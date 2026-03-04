# loteamento_app

A new Flutter project.

## 🚀 Deployment to GitHub Pages

This project is configured to automatically deploy to GitHub Pages using GitHub Actions.

### Steps to Deploy:

1. **Create a GitHub Repository**: Create a new repository on GitHub named `loteamento_app`.
2. **Add Remote**: Open your terminal in this project folder and run:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/loteamento_app.git
   ```
   *(Replace `YOUR_USERNAME` with your real GitHub username)*
3. **Push to GitHub**:
   ```bash
   git push -u origin main
   ```
4. **Enable GitHub Pages**:
   - Go to your repository on GitHub.
   - Click on **Settings** > **Pages**.
   - Under **Build and deployment** > **Source**, select **GitHub Actions**.

Once configured, every time you push to the `main` branch, the website will be updated automatically!

> [!TIP]
> **Data Priority**: The website now supports both JSON and CSV. For better reliability on GitHub Pages, JSON is preferred. If you update the CSV manually, it's a good idea to update the `lotes.json` as well (or ask me to do it for you).

## Getting Started

This project is a starting point for a Flutter application.
...
