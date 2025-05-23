# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "uts58"
  spec.version       = "0.0.1"
  spec.authors       = ["Arnt Gulbrandsen"]
  spec.email         = ["arnt@gulbrandsen.priv.no"]

  spec.summary       = %q{Ruby implementation of Unicode UTS58}
  spec.description   = %q{Ruby code to detect links in text, as specified by UTS58}
  spec.homepage      = "https://github.com/arnt/uts58"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.3")
  spec.licenses       = ["BSD-2-Clause"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z 2>/dev/null`.split("\x0").reject { |f| f.match(%r{^(bin|test|spec|features|rfcs)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "public_suffix"
  spec.add_dependency "simpleidn"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "diff-lcs", '~> 1.5.1'
end
