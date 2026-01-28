# NutriBase Legal Pages

This directory contains the legal pages and documentation for NutriBase, hosted via GitHub Pages.

## 📄 Pages Included

- **index.html** - Landing page with app overview and feature list
- **privacy.html** - Privacy Policy (required for App Store submission)
- **terms.html** - Terms of Service
- **support.html** - Support page with FAQs and contact information

## 🚀 Enabling GitHub Pages

1. **Push to GitHub**:
   ```bash
   git add docs/
   git commit -m "Add legal pages for App Store submission"
   git push origin main
   ```

2. **Enable GitHub Pages**:
   - Go to your repository on GitHub
   - Navigate to **Settings** > **Pages**
   - Under "Source", select **Deploy from a branch**
   - Under "Branch", select **main** and **/docs** folder
   - Click **Save**

3. **Wait for deployment** (usually 1-2 minutes)

4. **Your site will be available at**:
   ```
   https://[your-username].github.io/[repository-name]/
   ```

## 📱 App Store Submission URLs

Once GitHub Pages is enabled, use these URLs in App Connect:

- **Privacy Policy URL**: `https://[your-username].github.io/[repository-name]/privacy.html`
- **Terms of Service URL**: `https://[your-username].github.io/[repository-name]/terms.html`
- **Support URL**: `https://[your-username].github.io/[repository-name]/support.html`

## 🎨 Customization

Before publishing, update the following in the HTML files:

### Email Address
Replace `support@nutribase-app.com` with your actual support email in:
- privacy.html
- terms.html
- support.html

### Company Information
- Update copyright year if needed
- Add your company name if applicable
- Adjust legal disclaimers based on your jurisdiction

### Branding
- Update colors in the CSS if you want to match your app's branding
- Current gradient: Purple/blue (`#667eea` to `#764ba2`)

## 🔒 HTTPS

GitHub Pages automatically provides HTTPS for your site, which is required by Apple for legal page URLs.

## 🌐 Custom Domain (Optional)

If you want to use a custom domain like `nutribase-app.com`:

1. Create a file named `CNAME` in the docs directory with your domain:
   ```
   nutribase-app.com
   ```

2. Configure your domain's DNS settings:
   - Add an A record pointing to GitHub's IPs, or
   - Add a CNAME record pointing to `[your-username].github.io`

3. Enable HTTPS in GitHub Pages settings (after DNS propagates)

## 📝 Legal Review

**Important**: These legal documents are templates. Before submitting to the App Store, you should:

1. Review all content for accuracy
2. Consult with a lawyer if possible
3. Ensure compliance with GDPR, CCPA, and other regulations
4. Update the support email to your actual contact
5. Verify all technical claims match your actual implementation

## ✅ Checklist Before App Store Submission

- [ ] GitHub Pages is enabled and live
- [ ] All links work and display correctly
- [ ] Support email is updated to your actual email
- [ ] Privacy Policy reflects your actual data practices
- [ ] Terms of Service reviewed and customized
- [ ] HTTPS is enabled (automatic with GitHub Pages)
- [ ] URLs are added to App Store Connect

## 🔄 Updating Pages

To make changes:

1. Edit the HTML files in the docs directory
2. Commit and push changes to GitHub
3. GitHub Pages will automatically rebuild (takes 1-2 minutes)
4. Clear your browser cache to see updates

## 📞 Need Help?

If you need to customize these pages further, the HTML files use standard CSS and are fully self-contained - no build process required.
