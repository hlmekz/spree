#!/bin/sh
# Used in the sandbox rake task in Rakefile

set -e

case "$DB" in
mysql)
  RAILSDB="mysql"
  ;;
postgres)
  RAILSDB="postgresql"
  ;;
sqlite|'')
  RAILSDB="sqlite3"
  ;;
*)
  echo "Invalid DB specified: $DB"
  exit 1
  ;;
esac

rm -rf ./sandbox
bundle exec rails new sandbox --database="$RAILSDB" \
  --skip-bundle \
  --skip-git \
  --skip-keeps \
  --skip-rc \
  --skip-test \

if [ ! -d "sandbox" ]; then
  echo 'sandbox rails application failed'
  exit 1
fi

cd ./sandbox

cat <<RUBY >> Gemfile
gem 'devise'
gem 'spree', path: '..'
gem 'spree_emails', path: '../emails'
gem 'spree_sample', path: '../sample'
gem 'spree_admin', path: '../admin'
gem 'spree_storefront', path: '../storefront'
gem 'spree_i18n', github: 'spree-contrib/spree_i18n', branch: 'main'

group :test, :development do
  gem 'bullet'
  gem 'pry-byebug'
  gem 'awesome_print'
end
RUBY

touch config/initializers/bullet.rb

cat <<RUBY >> config/initializers/bullet.rb
if Rails.env.development? && defined?(Bullet)
  Bullet.enable = true
  Bullet.rails_logger = true
  Bullet.stacktrace_includes = [ 'spree_core', 'spree_storefront', 'spree_api', 'spree_admin', 'spree_emails' ]
end
RUBY

bundle update
bundle install --gemfile Gemfile

bin/rails importmap:install
bin/rails turbo:install
bin/rails stimulus:install

bin/rails db:drop || true
bin/rails db:create

# setup devise
bin/rails g devise:install
bin/rails g devise Spree::User

# setup spree
bin/rails g spree:install --auto-accept --user_class=Spree::User --authentication=devise --install_storefront=true --install_admin=true

# we also need to install the acts_as_taggable_on migrations
bin/rake acts_as_taggable_on_engine:install:migrations
