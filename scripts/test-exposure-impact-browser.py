#!/usr/bin/env python3
"""Real API-backed corporate impact UI; use the analytical impact fixture."""
import os
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
base=os.environ.get('EXPOSURE_BROWSER_URL','http://127.0.0.1:18120')
output=Path(os.environ.get('EXPOSURE_SCREENSHOT','/tmp/traderx-impact.png'))
with sync_playwright() as p:
    browser=p.chromium.launch()
    page=browser.new_page(viewport={'width':1440,'height':1120},device_scale_factor=1)
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(base+'/impact',wait_until='networkidle')
    expect(page.locator('#portfolio-count')).to_have_text('750')
    expect(page.locator('#exposure-value')).to_have_text('$393,750,000.00')
    expect(page.locator('#ranking>li')).to_have_count(20)
    expect(page.locator('#ranking>li').first.locator('.money')).to_have_text('$1,500,000.00')
    expect(page.locator('#ranking>li').first.locator('.paths')).to_contain_text('shared fund')
    page.select_option('#limit','10');page.click('#refresh')
    expect(page.locator('#ranking>li')).to_have_count(10)
    expect(page.locator('#portfolio-count')).to_have_text('750')
    expect(page.locator('#exposure-value')).to_have_text('$393,750,000.00')
    page.screenshot(path=str(output),full_page=True)
    page.set_viewport_size({'width':390,'height':844})
    page.screenshot(path=str(output.with_name(output.stem+'-mobile.png')),full_page=True)
    assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
    page.select_option('#target','IZERO');page.click('#refresh')
    expect(page.locator('#portfolio-count')).to_have_text('0')
    expect(page.locator('#coverage')).to_have_text('No portfolios are exposed to this group.')
    page.route('**/api/impact?**',lambda route:route.fulfill(status=503,content_type='application/json',body='{"error":"Projection unavailable"}'))
    page.click('#refresh');expect(page.locator('#error')).to_have_text('Projection unavailable')
    expect(page.locator('#portfolio-count')).to_have_text('—')
    expect(page.locator('#ranking')).to_be_empty();expect(page.locator('#status')).to_be_empty()
    page.locator('#single').click()
    expect(page.locator('#total')).to_have_text('100.00%')
    assert not errors,errors
    browser.close()
print('[ok] firm-wide count, ranking, fund paths, complete totals under limits, zero, failure and mobile:',output)
