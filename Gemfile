#  frozen_string_literal: true

ruby '3.3.1'

source 'https://rubygems.org'
gem 'kitchen-terraform', '~> 7.0.2'
# Force nori to v2.6 to avoid issue with inspec-gcp
# See https://github.com/inspec/inspec-gcp/issues/596
gem 'nori', '~> 2.6.0'
group :dev do
  # Transitive dependency in kitchen-terraform forces lower version of rubocop
  # gem 'rubocop', '~> 1.62.1', require: false
end
