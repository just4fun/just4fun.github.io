# GitHub Actions Setup Guide

## Migration from Travis CI to GitHub Actions

This project has been migrated from Travis CI to GitHub Actions for automated deployment.

### Workflow

1. When there are new commits to the `src` branch, GitHub Actions will automatically trigger
2. Build the Jekyll site using Ruby 3.0 environment
3. Deploy the built site to the `master` branch

### Setup Steps

1. **Ensure repository settings are correct**:
   - Make sure your repository has a `src` branch (source code branch)
   - Make sure your repository has a `master` branch (deployment branch)

2. **Configure GitHub Pages**:
   - Enable GitHub Pages in repository settings
   - Select `master` branch as the source branch

3. **Permission settings**:
   - GitHub Actions will automatically use `GITHUB_TOKEN`, no additional configuration needed
   - Ensure repository Actions permissions are enabled

### File Structure

- `.github/workflows/deploy.yml` - GitHub Actions workflow configuration
- `.github/scripts/deploy.sh` - Deployment script (backup)

### Differences from Travis CI

- **Trigger conditions**: Only triggers on pushes to `src` branch
- **Deployment method**: Direct push to `master` branch, not using gh-pages
- **Environment**: Uses Ubuntu latest and Ruby 3.0

### Troubleshooting

If deployment fails, check:
1. Ensure the `src` branch exists and contains source code
2. Ensure Jekyll build succeeds
3. Check GitHub Actions logs for detailed error messages