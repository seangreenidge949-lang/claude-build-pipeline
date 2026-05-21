#!/usr/bin/env python3
"""
Scrapling-based web scraper for Claude Code.
Supports static HTTP fetching, JS rendering, Cloudflare bypass, and persistent login sessions.

Usage:
    scrape.py <url> [options]          Scrape a URL
    scrape.py --login <url>            Open browser for interactive login (QR code etc.)
    scrape.py --check-login <domain>   Check if login session exists for domain

Options:
    --mode auto|http|stealth    Fetch mode (default: auto)
    --css <selector>            Extract specific elements via CSS selector
    --format markdown|text|html Output format (default: markdown)
    --timeout <seconds>         Request timeout (default: 30)
    --no-cloudflare             Disable Cloudflare solver
    --profile <name>            Browser profile name (default: auto from domain)
    --no-profile                Don't use any saved profile
"""

import sys
import os
import argparse
import time
from pathlib import Path
from urllib.parse import urlparse

PROFILES_DIR = Path.home() / ".claude" / "browser-profiles"


# ── Profile Management ──────────────────────────────────────────────

def domain_from_url(url: str) -> str:
    """Extract registered domain for profile lookup."""
    hostname = urlparse(url).hostname or ""
    # Strip common prefixes to normalize: s.weibo.com → weibo.com
    parts = hostname.split(".")
    if len(parts) > 2:
        return ".".join(parts[-2:])
    return hostname


def get_profile_dir(url: str, profile_name: str = None) -> Path:
    """Get or create profile directory for a domain."""
    name = profile_name or domain_from_url(url)
    profile_dir = PROFILES_DIR / name
    profile_dir.mkdir(parents=True, exist_ok=True)
    return profile_dir


def has_profile(url: str, profile_name: str = None) -> bool:
    """Check if a persistent profile exists for this domain."""
    name = profile_name or domain_from_url(url)
    profile_dir = PROFILES_DIR / name
    # A valid profile has at least some browser data files
    return profile_dir.exists() and any(profile_dir.iterdir())


# ── Login Flow ──────────────────────────────────────────────────────

def login_interactive(url: str, profile_name: str = None):
    """Open headful browser for user to complete login (QR code, password, etc.).

    Uses Playwright (not Patchright) for reliable GUI window on macOS.
    The persistent profile is shared with Patchright for subsequent stealth fetches.
    """
    from playwright.sync_api import sync_playwright

    profile_dir = get_profile_dir(url, profile_name)
    domain = domain_from_url(url)

    sys.stderr.write(f"[login] Opening browser for {domain}...\n")
    sys.stderr.write(f"[login] Profile: {profile_dir}\n")
    sys.stderr.write(f"[login] Please complete login in the browser window.\n")
    sys.stderr.write(f"[login] The browser will close automatically after 5 minutes, or when login is detected.\n")

    with sync_playwright() as p:
        ctx = p.chromium.launch_persistent_context(
            str(profile_dir),
            headless=False,
            viewport={"width": 1280, "height": 800},
            locale="zh-CN",
        )
        page = ctx.new_page()
        page.goto(url, wait_until="domcontentloaded")

        original_url = page.url
        sys.stderr.write(f"[login] Page loaded: {original_url}\n")
        sys.stderr.write(f"[login] Waiting for login...\n")

        # Poll for login completion: up to 5 minutes, check every 3s
        for i in range(100):
            page.wait_for_timeout(3000)
            current_url = page.url

            # Detect URL change away from login page
            if current_url != original_url and "login" not in current_url.lower() and "signin" not in current_url.lower():
                sys.stderr.write(f"[login] Redirected to {current_url} — login successful!\n")
                page.wait_for_timeout(3000)  # Let page stabilize
                break

            # Every 30s print a reminder
            if i > 0 and i % 10 == 0:
                remaining = (100 - i) * 3
                sys.stderr.write(f"[login] Still waiting... ({remaining}s remaining)\n")
        else:
            sys.stderr.write(f"[login] Timeout reached. Saving profile as-is.\n")

        ctx.close()

    sys.stderr.write(f"[login] Profile saved to {profile_dir}\n")
    print(f'{{"status": "saved", "domain": "{domain}", "profile": "{profile_dir}"}}')


def check_login(domain: str):
    """Check if a login profile exists and is usable."""
    profile_dir = PROFILES_DIR / domain
    if not profile_dir.exists() or not any(profile_dir.iterdir()):
        print(f'{{"domain": "{domain}", "logged_in": false, "reason": "no_profile"}}')
        return

    # Profile exists — use same Playwright engine as login to verify session
    from playwright.sync_api import sync_playwright

    test_urls = {
        "weibo.com": "https://s.weibo.com/top/summary",
        "zhihu.com": "https://www.zhihu.com/hot",
        "xiaohongshu.com": "https://www.xiaohongshu.com/explore",
    }
    test_url = test_urls.get(domain, f"https://www.{domain}/")

    try:
        with sync_playwright() as p:
            ctx = p.chromium.launch_persistent_context(
                str(profile_dir),
                headless=True,
                locale="zh-CN",
            )
            page = ctx.new_page()
            page.goto(test_url, wait_until="domcontentloaded", timeout=30000)
            page.wait_for_timeout(3000)

            content = page.content()
            # Check for login wall indicators in page content
            login_keywords = ["登录", "signin", "login", "扫码", "qrcode"]
            has_login_wall = sum(1 for kw in login_keywords if kw.lower() in content.lower())

            # Check for meaningful content
            texts = page.query_selector_all("body *")
            text_count = len([el for el in texts if (el.text_content() or "").strip()])

            ctx.close()

            if text_count > 20 and has_login_wall < 3:
                print(f'{{"domain": "{domain}", "logged_in": true, "content_items": {text_count}}}')
            else:
                print(f'{{"domain": "{domain}", "logged_in": false, "reason": "session_expired"}}')
    except Exception as e:
        print(f'{{"domain": "{domain}", "logged_in": false, "reason": "error: {e}"}}')


# ── Fetchers ────────────────────────────────────────────────────────

def fetch_http(url: str, timeout: int = 30) -> "Response":
    """Fast HTTP fetch with TLS fingerprint impersonation."""
    from scrapling.fetchers import Fetcher
    return Fetcher.get(
        url,
        stealthy_headers=True,
        impersonate="chrome",
        timeout=timeout,
    )


def fetch_stealth(url: str, timeout: int = 60, solve_cf: bool = True,
                   profile_dir: str = None) -> "Response":
    """Stealth browser fetch with Cloudflare bypass and optional login profile."""
    from scrapling.engines._browsers._stealth import StealthySession

    kwargs = dict(
        headless=True,
        network_idle=True,
        solve_cloudflare=solve_cf,
    )
    if profile_dir:
        kwargs["user_data_dir"] = profile_dir

    with StealthySession(**kwargs) as session:
        return session.fetch(url)


def fetch_api_intercept(url: str, profile_dir: str = None,
                        api_pattern: str = None) -> str:
    """Fetch SPA pages by intercepting API responses instead of parsing DOM.

    Used for sites like Xiaohongshu where content is loaded via JSON APIs,
    not rendered into DOM.
    """
    from playwright.sync_api import sync_playwright
    import json

    # Known API patterns for SPA sites
    KNOWN_API_PATTERNS = {
        "xiaohongshu.com": "/api/sns/web/v1/search/notes",
    }

    domain = domain_from_url(url)
    pattern = api_pattern or KNOWN_API_PATTERNS.get(domain)
    if not pattern:
        return None

    captured = []

    with sync_playwright() as p:
        kwargs = {"headless": True, "locale": "zh-CN"}
        if profile_dir:
            ctx = p.chromium.launch_persistent_context(profile_dir, **kwargs)
        else:
            browser = p.chromium.launch(**kwargs)
            ctx = browser.new_context()

        page = ctx.new_page()

        def on_response(response):
            if pattern in response.url:
                try:
                    captured.append(response.json())
                except Exception:
                    pass

        page.on("response", on_response)
        page.goto(url, wait_until="networkidle", timeout=30000)
        page.wait_for_timeout(5000)
        ctx.close()

    if not captured:
        return None

    # Format captured API data based on domain
    if domain == "xiaohongshu.com":
        return _format_xiaohongshu(captured[0])

    return json.dumps(captured[0], ensure_ascii=False, indent=2)


def _format_xiaohongshu(data: dict) -> str:
    """Format Xiaohongshu search API response as readable text."""
    items = data.get("data", {}).get("items", [])
    if not items:
        return None

    lines = [f"小红书搜索结果: {len(items)} 条\n"]
    for i, item in enumerate(items, 1):
        card = item.get("note_card", {})
        title = card.get("display_title", "").strip()
        if not title:
            continue
        user = card.get("user", {}).get("nickname", "")
        likes = card.get("interact_info", {}).get("liked_count", "")
        note_id = item.get("id", "")
        note_type = card.get("type", "")
        url = f"https://www.xiaohongshu.com/explore/{note_id}" if note_id else ""
        lines.append(f"{i}. {title}")
        lines.append(f"   作者: {user} | 点赞: {likes} | 类型: {note_type}")
        if url:
            lines.append(f"   链接: {url}")
    return "\n".join(lines)


# Domains that need API interception instead of DOM parsing
API_INTERCEPT_DOMAINS = {"xiaohongshu.com"}


def has_content(page) -> bool:
    """Check if page has meaningful content (not just login/error page)."""
    texts = page.css("body *::text").getall()
    meaningful = [t.strip() for t in texts if t.strip() and len(t.strip()) > 2]
    return len(meaningful) > 5


# ── Output Formatters ───────────────────────────────────────────────

def to_markdown(page, css_selector: str = None) -> str:
    """Convert page content to markdown."""
    lines = []

    title = page.css("title::text").get()
    if title:
        lines.append(f"# {title.strip()}")
        lines.append("")

    if css_selector:
        elements = page.css(css_selector)
        if not elements:
            lines.append(f"*No elements found for selector: `{css_selector}`*")
        else:
            for el in elements:
                text = el.css("::text").getall()
                text = " ".join(t.strip() for t in text if t.strip())
                if text:
                    lines.append(f"- {text}")
        return "\n".join(lines)

    for el in page.css("body *"):
        tag = el.tag if hasattr(el, "tag") else ""
        text_parts = el.css("::text").getall()
        text = " ".join(t.strip() for t in text_parts if t.strip())
        if not text:
            continue

        if tag in ("h1",):
            lines.append(f"\n# {text}")
        elif tag in ("h2",):
            lines.append(f"\n## {text}")
        elif tag in ("h3",):
            lines.append(f"\n### {text}")
        elif tag in ("h4", "h5", "h6"):
            lines.append(f"\n#### {text}")
        elif tag == "li":
            lines.append(f"- {text}")
        elif tag == "a":
            href = el.attrib.get("href", "")
            if href and not href.startswith("#") and not href.startswith("javascript"):
                lines.append(f"[{text}]({href})")
        elif tag in ("p", "div", "span", "td", "th"):
            if len(text) > 3 and text not in [l.strip("- #[]()") for l in lines[-5:]]:
                lines.append(text)

    result = []
    for line in lines:
        if not result or line != result[-1]:
            result.append(line)

    return "\n".join(result)


def to_text(page, css_selector: str = None) -> str:
    """Extract plain text."""
    if css_selector:
        elements = page.css(css_selector)
        texts = []
        for el in elements:
            t = " ".join(el.css("::text").getall()).strip()
            if t:
                texts.append(t)
        return "\n".join(texts)

    texts = page.css("body *::text").getall()
    return "\n".join(t.strip() for t in texts if t.strip())


def to_html(page, css_selector: str = None) -> str:
    """Return raw HTML."""
    if css_selector:
        elements = page.css(css_selector)
        return "\n".join(str(el) for el in elements)
    return str(page)


# ── Mode Detection ──────────────────────────────────────────────────

STEALTH_DOMAINS = {
    "weibo.com", "s.weibo.com", "m.weibo.com",
    "taobao.com", "www.taobao.com", "item.taobao.com", "s.taobao.com",
    "tmall.com", "www.tmall.com", "detail.tmall.com",
    "jd.com", "www.jd.com", "item.jd.com", "search.jd.com",
    "xiaohongshu.com", "www.xiaohongshu.com",
    "douyin.com", "www.douyin.com",
    "bilibili.com", "www.bilibili.com",
    "zhihu.com", "www.zhihu.com",
    "producthunt.com", "www.producthunt.com",
}


def auto_detect_mode(url: str) -> str:
    """Detect whether to use http or stealth mode based on domain."""
    domain = urlparse(url).hostname or ""
    if domain in STEALTH_DOMAINS:
        return "stealth"
    return "http"


# ── Main ────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Scrape web pages with anti-detection and login support")

    # Mutually exclusive primary actions
    group = parser.add_mutually_exclusive_group()
    group.add_argument("url", nargs="?", help="URL to scrape")
    group.add_argument("--login", metavar="URL", help="Open browser for interactive login")
    group.add_argument("--check-login", metavar="DOMAIN", help="Check if login session exists")

    # Scrape options
    parser.add_argument("--mode", choices=["auto", "http", "stealth"], default="auto",
                        help="Fetch mode (default: auto)")
    parser.add_argument("--css", help="CSS selector to extract specific elements")
    parser.add_argument("--format", choices=["markdown", "text", "html"], default="markdown",
                        dest="output_format", help="Output format (default: markdown)")
    parser.add_argument("--timeout", type=int, default=30, help="Timeout in seconds")
    parser.add_argument("--no-cloudflare", action="store_true", help="Disable Cloudflare solver")

    # Profile options
    parser.add_argument("--profile", help="Browser profile name (default: auto from domain)")
    parser.add_argument("--no-profile", action="store_true", help="Don't use any saved profile")

    args = parser.parse_args()

    # ── Login mode ──
    if args.login:
        login_interactive(args.login, args.profile)
        return

    # ── Check login mode ──
    if args.check_login:
        check_login(args.check_login)
        return

    # ── Scrape mode ──
    if not args.url:
        parser.print_help()
        sys.exit(1)

    # Determine mode
    mode = args.mode
    if mode == "auto":
        mode = auto_detect_mode(args.url)

    # Determine profile — check regardless of mode (auto-escalate may need it)
    profile_dir = None
    if not args.no_profile and has_profile(args.url, args.profile):
        profile_dir = str(get_profile_dir(args.url, args.profile))
        sys.stderr.write(f"[profile] Using saved profile: {profile_dir}\n")

    # Fetch
    start = time.time()
    page = None
    used_mode = mode
    api_output = None  # For API-intercept mode (SPA sites like Xiaohongshu)

    # Check if this domain needs API interception
    domain = domain_from_url(args.url)
    if domain in API_INTERCEPT_DOMAINS and mode == "stealth":
        sys.stderr.write(f"[api-intercept] {domain} uses SPA rendering, intercepting API...\n")
        api_output = fetch_api_intercept(args.url, profile_dir=profile_dir)
        if api_output:
            used_mode = "api-intercept"
        else:
            sys.stderr.write("[api-intercept] No API data captured, falling back to DOM...\n")

    if not api_output:
        try:
            if mode == "http":
                page = fetch_http(args.url, timeout=args.timeout)
                if not has_content(page):
                    sys.stderr.write("[auto-escalate] HTTP returned empty content, switching to stealth...\n")
                    page = fetch_stealth(args.url, timeout=args.timeout,
                                         solve_cf=not args.no_cloudflare,
                                         profile_dir=profile_dir)
                    used_mode = "stealth (auto-escalated)"
            else:
                page = fetch_stealth(args.url, timeout=args.timeout,
                                     solve_cf=not args.no_cloudflare,
                                     profile_dir=profile_dir)
        except Exception as e:
            if mode == "http":
                sys.stderr.write(f"[fallback] HTTP failed ({e}), trying stealth...\n")
                try:
                    page = fetch_stealth(args.url, timeout=args.timeout,
                                         solve_cf=not args.no_cloudflare,
                                         profile_dir=profile_dir)
                    used_mode = "stealth (fallback)"
                except Exception as e2:
                    print(f"Error: Both HTTP and stealth modes failed.\nHTTP: {e}\nStealth: {e2}",
                          file=sys.stderr)
                    sys.exit(1)
            else:
                print(f"Error: {type(e).__name__}: {e}", file=sys.stderr)
                sys.exit(1)

    elapsed = time.time() - start

    # Format output
    if api_output:
        output = api_output
    else:
        formatters = {
            "markdown": to_markdown,
            "text": to_text,
            "html": to_html,
        }
        output = formatters[args.output_format](page, args.css)

    profile_info = f" | profile={profile_dir}" if profile_dir else ""
    sys.stderr.write(f"[scraped] {args.url} | mode={used_mode}{profile_info} | {elapsed:.1f}s\n")

    print(output)


if __name__ == "__main__":
    main()
