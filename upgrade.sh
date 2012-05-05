export PATH="/srv/.rbenv/shims:/srv/.rbenv/bin:$PATH"
cd /srv/geo && rbenv rehash && bundle install && bundle exec ruby upgrade.rb
