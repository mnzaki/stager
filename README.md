## Stager
A simple application to facilitate staging rails applications.

### Instructions
Edit `config.yml` to taste. You can use a `secrets.yml` file (which is
automatically included) to keep your passwords and tokens.

Make sure that the paths configured in `authorized_keys` and `git_data_path`
exist and are writable by the user that will run stager.

You will need a redis server on the localhost (FIXME: make this
configurable....)

You can run stager like so:
```
bundle exec thin -R config.ru -p 9292 start
```
And sidekiq:
```
bundle exec sidekiq -r ./app.rb
```

You can use monit to run (and monitor) the servers instead. Use the files at
`config/monit-stager.conf` and `config/monit-sidekiq.conf` for inspiration.

Disclaimer: this was hacked together quickly and is fairly buggy.
