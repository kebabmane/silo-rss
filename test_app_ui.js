const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 }
  });
  const page = await context.newPage();

  try {
    console.log('📱 Starting Silo UI Review\n');

    // 1. Landing Page
    console.log('1️⃣  Loading landing page...');
    await page.goto('http://localhost:3000/', { waitUntil: 'networkidle' });
    await page.screenshot({ path: 'landing-page.png' });
    console.log('✅ Screenshot: landing-page.png\n');

    // Get page content for analysis
    const landingTitle = await page.title();
    console.log(`Title: ${landingTitle}`);

    // Check for elements
    const hasOnboarding = await page.locator('text=/onboarding|welcome|get started/i').isVisible({ timeout: 1000 }).catch(() => false);
    console.log(`Page includes onboarding: ${hasOnboarding ? '✅ Yes' : '❌ No'}\n`);

    // 2. Check if there's a login page
    console.log('2️⃣  Checking login/signup flow...');
    const authLinks = await page.locator('a:has-text("Sign up"), a:has-text("Login"), a:has-text("Register")').count();
    if (authLinks > 0) {
      console.log('✅ Found auth links');
      const firstAuthLink = page.locator('a:has-text("Sign"), a:has-text("Login")').first();
      await firstAuthLink.click();
      await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {});
      await page.screenshot({ path: 'login-page.png' });
      console.log('✅ Screenshot: login-page.png\n');
    } else {
      console.log('ℹ️  No auth links found on landing page\n');
    }

    // 3. Try to access dashboard (if logged out, should redirect)
    console.log('3️⃣  Checking dashboard...');
    await page.goto('http://localhost:3000/dashboard', { waitUntil: 'networkidle' });
    await page.screenshot({ path: 'dashboard-view.png' });
    const currentUrl = page.url();
    console.log(`Dashboard URL: ${currentUrl}`);
    console.log('✅ Screenshot: dashboard-view.png\n');

    // 4. Check admin area
    console.log('4️⃣  Checking admin area...');
    await page.goto('http://localhost:3000/admin', { waitUntil: 'networkidle' });
    await page.screenshot({ path: 'admin-area.png' });
    console.log('✅ Screenshot: admin-area.png\n');

    // 5. Analyze layout and colors
    console.log('5️⃣  Analyzing visual design...');
    const styles = await page.evaluate(() => {
      const html = document.documentElement;
      const isDarkMode = html.classList.contains('dark');
      const bodyBg = window.getComputedStyle(document.body).backgroundColor;
      return {
        isDarkMode,
        bodyBackground: bodyBg,
        htmlClasses: html.className
      };
    });
    console.log(`Dark mode enabled: ${styles.isDarkMode ? '✅ Yes' : '❌ No'}`);
    console.log(`Background color: ${styles.bodyBackground}`);
    console.log(`HTML Classes: ${styles.htmlClasses}\n`);

    // 6. Check responsive design
    console.log('6️⃣  Testing mobile responsive view...');
    const mobileContext = await browser.newContext({
      viewport: { width: 375, height: 812 }
    });
    const mobilePage = await mobileContext.newPage();
    await mobilePage.goto('http://localhost:3000/');
    await mobilePage.screenshot({ path: 'mobile-view.png' });
    console.log('✅ Screenshot: mobile-view.png\n');
    await mobileContext.close();

    // 7. Get all links and navigation elements
    console.log('7️⃣  Analyzing page structure...');
    const navElements = await page.locator('nav, header, [role="navigation"]').count();
    console.log(`Navigation elements found: ${navElements}`);

    const buttons = await page.locator('button').count();
    console.log(`Total buttons on page: ${buttons}`);

    const links = await page.locator('a').count();
    console.log(`Total links on page: ${links}\n`);

    // 8. Check for accessibility
    console.log('8️⃣  Checking accessibility elements...');
    const headings = await page.locator('h1, h2, h3').count();
    console.log(`Heading elements: ${headings}`);

    const altImages = await page.locator('img[alt]').count();
    const totalImages = await page.locator('img').count();
    console.log(`Images with alt text: ${altImages}/${totalImages}\n`);

    console.log('✅ UI Review Complete!\n');
    console.log('📸 Generated screenshots:');
    console.log('  - landing-page.png');
    console.log('  - login-page.png (if available)');
    console.log('  - dashboard-view.png');
    console.log('  - admin-area.png');
    console.log('  - mobile-view.png');

  } catch (error) {
    console.error('❌ Error during UI review:', error.message);
  } finally {
    await browser.close();
  }
})();
