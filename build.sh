#!/bin/bash
# Build and sanity-check the uts58 gem and the npm package side by
# side, from a clean checkout at a version tag, so that what ships is
# exactly what's committed at the tag, and the gem and npm builds
# carry the same version. The publish commands at the end are
# intentionally commented out; uncomment them (with rubygems/npm
# credentials in place) to actually release.
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
cd "$root"

# A release must be reproducible from git at the tag, so refuse to build from a
# dirty tree or a commit that isn't the tag.
if [ -n "$(git status --porcelain)" ]; then
	echo "error: working tree has uncommitted changes; commit or stash first" >&2
	git status --short >&2
	exit 1
fi
tag=$(git describe --exact-match --tags HEAD 2>/dev/null || true)
if [ -z "$tag" ]; then
	echo "error: HEAD is not at a tag; tag the release first, e.g. git tag v<version>" >&2
	exit 1
fi
version=${tag#v}

# The tag is the source of truth; every version string in the tree must match
# it. The gemspec and the Uts58::VERSION constant are independent (the gemspec
# does not read the constant), so the constant can drift — catch that here
# rather than shipping a gem whose VERSION disagrees with its package.
# The tag is the source of truth; every independent version string must match
# it. The gemspec derives its version from Uts58::VERSION (lib/uts58/version.rb),
# so that one read covers both. Gemfile.lock pins the gem's own version via the
# `gemspec` directive and goes stale if the version was bumped without
# re-resolving; it's gitignored and regenerated, so a fresh clone won't have it.
if [ ! -f ruby/Gemfile.lock ]; then
	echo "error: ruby/Gemfile.lock is missing; run 'bundle install' in ruby/ first" >&2
	exit 1
fi
npm_version=$(node -p "require('./javascript/package.json').version")
gem_version=$(ruby -e 'puts Gem::Specification.load("ruby/uts58.gemspec").version')
lock_version=$(ruby -e 'puts File.read("ruby/Gemfile.lock")[/^\s*uts58 \(([^)]+)\)/, 1]')
for pair in \
	"javascript/package.json:$npm_version" \
	"ruby/uts58.gemspec:$gem_version" \
	"ruby/Gemfile.lock:$lock_version"
do
	if [ "${pair#*:}" != "$version" ]; then
		echo "error: ${pair%:*} has version ${pair#*:}, but the tag is $tag" >&2
		exit 1
	fi
done

echo "== Building uts58 $version (tag $tag) =="

echo "== Ruby gem =="
cd "$root/ruby"
bundle install --quiet
bundle exec rspec
# --strict turns gemspec warnings into errors, the closest gem has to a lint of
# the packaged metadata.
gem build uts58.gemspec --strict
gem="$PWD/uts58-$version.gem"

echo "== npm package =="
cd "$root/javascript"
npm ci
npm test
# --dry-run runs the full publish pipeline (prepack, file selection) and prints
# the tarball contents without uploading anything.
npm publish --dry-run
npm pack
tgz="$PWD/agulbra-uts58-$version.tgz"

echo
echo "Built and checked at tag $tag:"
echo "  gem: $gem"
echo "  npm: $tgz"

# To publish, uncomment these once the credentials are in place:
# gem push "$gem"
# npm publish "$tgz"
