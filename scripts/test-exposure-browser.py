#!/usr/bin/env python3
"""Exercise the real API-backed UI and retain a screenshot."""
import os
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
base=os.environ.get('EXPOSURE_BROWSER_URL','http://127.0.0.1:18120')
output=Path(os.environ.get('EXPOSURE_SCREENSHOT','/tmp/traderx-exposure.png'))
with sync_playwright() as p:
    browser=p.chromium.launch()
    page=browser.new_page(viewport={'width':1440,'height':1120},device_scale_factor=1)
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(base,wait_until='networkidle')
    expect(page.locator('#total')).to_have_text('14.00%')
    expect(page.locator('#direct')).to_have_text('2.00%')
    expect(page.locator('#indirect')).to_have_text('12.00%')
    expect(page.locator('#paths tr')).to_have_count(2)
    expect(page.locator('#valuation')).to_have_text('Exposure $14,000.00 of $100,000.00')
    expect(page.locator('.brand')).to_have_text('TraderX')
    page.screenshot(path=str(output),full_page=True)
    page.select_option('#target','Z1G');page.click('#refresh')
    expect(page.locator('#total')).to_have_text('0.00%')
    # A failed response must clear the successful result instead of leaving a stale number.
    page.route('**/api/exposure?**',lambda route:route.fulfill(status=503,content_type='application/json',body='{"error":"Projection unavailable"}'))
    page.click('#refresh');expect(page.locator('#error')).to_have_text('Projection unavailable')
    expect(page.locator('#total')).to_have_text('—')
    for selector in ('#valuation','#status','#count'):
        expect(page.locator(selector)).to_be_empty()
    assert not errors,errors
    page.set_viewport_size({'width':390,'height':844})
    page.screenshot(path=str(output.with_name(output.stem+'-mobile.png')),full_page=True)
    browser.close()
print('[ok] browser totals, explanations, zero exposure, errors, screenshot:',output)
