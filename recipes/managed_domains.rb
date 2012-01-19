include_recipe "glassfish::default"

included_authbind = false

node[:glassfish][:domain_definitions].each_pair do |domain_key, definition|
  domain_key = domain_key.to_s

  Chef::Log.info "Defining GlassFish Domain #{domain_key}"

  directory "#{node[:glassfish][:domains_dir]}" do
    owner node[:glassfish][:user]
    group node[:glassfish][:group]
    mode "0700"
  end

  if definition[:config][:password]
    template "#{node[:glassfish][:domains_dir]}/#{domain_key}_admin_passwd" do
      source "password.erb"
      owner node[:glassfish][:user]
      group node[:glassfish][:group]
      mode "0600"
      variables :domain_name => domain_key
    end
  end

  requires_authbind = (definition[:config][:port] && definition[:config][:port] < 1024) || (definition[:config][:admin_port] && definition[:config][:admin_port] < 1024)

  if requires_authbind && !included_authbind
    included_authbind = true
    include_recipe "authbind"
  end

  glassfish_domain domain_key do
    max_memory definition[:config][:max_memory] if definition[:config][:max_memory]
    max_perm_size definition[:config][:max_perm_size] if definition[:config][:max_perm_size]
    max_stack_size definition[:config][:max_stack_size] if definition[:config][:max_stack_size]
    port definition[:config][:port] if definition[:config][:port]
    admin_port definition[:config][:admin_port] if definition[:config][:admin_port]
    username definition[:config][:username] if definition[:config][:username]
    password definition[:config][:password] if definition[:config][:password]
  end

  definition[:extra_libraries].each do |extra_library|
    library_location = "#{node[:glassfish][:domains_dir]}/#{domain_key}/lib/ext/#{::File.basename(extra_library)}"
    remote_file library_location do
      source extra_library
      mode "0640"
      owner node[:glassfish][:user]
      group node[:glassfish][:group]
      not_if { ::File.exists?(library_location) }
      #notifies :restart, resources(:service => "glassfish-#{domain_key}")
    end
  end

  definition[:jvm_options].each do |jvm_option|
    glassfish_jvm_option jvm_option do
      domain_name domain_key
    end
  end

  definition[:sets].each do |set|
    glassfish_property set do
      domain_name domain_key
    end
  end

  definition[:realms].each_pair do |key, configuration|
    glassfish_auth_realm key.to_s do
      domain_name domain_key
      parameters configuration[:parameters]
    end
  end

  definition[:jdbc_connection_pools].each_pair do |key, configuration|
    key = key.to_s
    glassfish_jdbc_connection_pool key do
      domain_name domain_key
      parameters configuration[:parameters]
    end
    configuration[:resources].each_pair do |resource_name, resource_configuration|
      params = ["--connectionpoolid #{key}"]
      params += resource_configuration[:parameters] if resource_configuration[:parameters]
      glassfish_jdbc_resource resource_name.to_s do
        domain_name domain_key
        parameters params
      end
    end
  end

  definition[:deployables].each_pair do |deployable_key, configuration|
    glassfish_deployable deployable_key.to_s do
      domain_name domain_key
      version configuration[:version]
      url configuration[:url]
      context_root configuration[:context_root] if configuration[:context_root]
    end
  end
end

node[:glassfish][:mq_servers].each_pair do |instance, definition|
  instance = instance.to_s

  Chef::Log.info "Defining GlassFish #{instance} OpenMQ Server"

  directory "/var/omq" do
    owner node[:glassfish][:user]
    group node[:glassfish][:group]
    mode "0700"
  end

  requires_authbind = (definition[:port] && definition[:port] < 1024)

  if requires_authbind && !included_authbind
    included_authbind = true
    include_recipe "authbind"
  end

  glassfish_mq instance do
    max_memory definition[:max_memory] if definition[:max_memory]
    max_stack_size definition[:max_stack_size] if definition[:max_stack_size]
    port definition[:port] if definition[:port]
    jmx_port definition[:jmx_port] if definition[:jmx_port]
    var_home definition[:var_home] if definition[:var_home]
    access_control_rules definition[:access_control_rules] if definition[:access_control_rules]
  end

  definition[:users].each_pair do |username, user_details|
    glassfish_mq_user username do
      password user_details[:password]
      group user_details[:group] if user_details[:group]
      active user_details[:active] if user_details[:active]
      instance instance
      var_home definition[:var_home] if definition[:var_home]
    end
  end
end
