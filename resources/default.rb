resource_name :ctf_moscow_2019_101_website

property :fqdn, String, name_property: true

property :user, String, required: true
property :group, String, required: true

property :github_repository, String, default: 'VolgaCTF/ctf-moscow-2019-101'
property :revision, String, default: 'master'

property :hsts_max_age, Integer, default: 15_768_000
property :oscp_stapling, [TrueClass, FalseClass], default: true
property :resolvers, Array, default: %w(8.8.8.8 1.1.1.1 8.8.4.4 1.0.0.1)
property :resolver_valid, Integer, default: 600
property :resolver_timeout, Integer, default: 10

property :listen_ipv6, [TrueClass, FalseClass], default: false
property :default_server, [TrueClass, FalseClass], default: false
property :access_log_options, String, default: 'combined'
property :error_log_options, String, default: 'warn'

default_action :install

action :install do
  repository_url = "https://github.com/#{new_resource.github_repository}"

  base_dir = ::File.join('/var/www', new_resource.fqdn)

  directory base_dir do
    owner new_resource.user
    group new_resource.group
    mode 0o755
    recursive true
    action :create
  end

  git base_dir do
    repository repository_url
    revision new_resource.revision
    enable_checkout false
    user new_resource.user
    group new_resource.group
    action :sync
  end

  vhost_vars = {
    fqdn: new_resource.fqdn,
    listen_ipv6: new_resource.listen_ipv6,
    default_server: new_resource.default_server,
    access_log_options: new_resource.access_log_options,
    error_log_options: new_resource.error_log_options,
    doc_root: base_dir,
    hsts_max_age: new_resource.hsts_max_age,
    oscp_stapling: new_resource.oscp_stapling,
    resolvers: new_resource.resolvers,
    resolver_valid: new_resource.resolver_valid,
    resolver_timeout: new_resource.resolver_timeout,
    certificate_entries: []
  }

  tls_rsa_certificate new_resource.fqdn do
    action :deploy
  end

  tls = ::ChefCookbook::TLS.new(node)
  vhost_vars[:certificate_entries] << tls.rsa_certificate_entry(new_resource.fqdn)

  if tls.has_ec_certificate?(new_resource.fqdn)
    tls_ec_certificate new_resource.fqdn do
      action :deploy
    end

    vhost_vars[:certificate_entries] << tls.ec_certificate_entry(new_resource.fqdn)
  end

  nginx_vhost new_resource.fqdn do
    cookbook 'ctf-moscow-2019-101'
    template 'nginx.vhost.erb'
    variables(lazy {
      vhost_vars.merge(
        access_log: ::File.join(node.run_state['nginx']['log_dir'], "#{new_resource.fqdn}_access.log"),
        error_log: ::File.join(node.run_state['nginx']['log_dir'], "#{new_resource.fqdn}_error.log")
      )
    })
    action :enable
  end
end
