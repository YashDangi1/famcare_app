# FamCare Workflow Guidelines

## Clean Git Commits
1. Use conventional commits format: `<type>(<scope>): <description>`
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
2. Write clear, concise commit messages that describe the change
3. Keep commits atomic (one change per commit)

## Updating Native Files
When introducing new dependencies that require native configuration:
1. Update `android/app/src/main/AndroidManifest.xml` for Android permissions/features
2. Update `ios/Runner/Info.plist` for iOS permissions/features
3. Always document the changes in commit messages
4. Test on both Android and iOS after modifying native files