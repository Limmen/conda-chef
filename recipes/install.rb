if node['kernel']['machine'] != 'x86_64'
   Chef::Log.fatal!("Unrecognized node.kernel.machine=#{node['kernel']['machine']}; Only x86_64", 1)
end

package "bzip2"

group node['conda']['group']
user node['conda']['user'] do
  gid node['conda']['group']
  manage_home true
  home "/home/#{node['conda']['user']}"
  shell "/bin/bash"
  action :create
  system true
  not_if "getent passwd #{node['conda']['user']}"
end

directory node['conda']['dir']  do
  owner node['conda']['user']
  group node['conda']['group']
  mode '755'
  action :create
  not_if { File.directory?(node['conda']['dir']) }
end

script = File.basename(node['conda']['url'])
installer_path = "#{Chef::Config[:file_cache_path]}/#{script}"

remote_file installer_path do
  source node['conda']['url']
#  checksum installer_checksum
  user node['conda']['user']
  group node['conda']['group']
  mode 0755
  action :create_if_missing
end

# Template condarc to set mirrors/channels
template "/home/#{node['conda']['user']}/.condarc" do
  source "condarc.erb"
  user node['conda']['user']
  group node['conda']['group']
  mode 0755
end

bash 'run_conda_installer' do
  user node['conda']['user']
  group node['conda']['group']
  code <<-EOF
   #{installer_path} -b -p #{node['conda']['home']}
  EOF
  not_if { File.directory?(node['conda']['home']) }
end

link node['conda']['base_dir'] do
  owner node['conda']['user']
  group node['conda']['group']
  to node['conda']['home']
end

dirs=%w{ envs pkgs lib }
for d in dirs do
  bash 'run_conda_installer_#{d}' do
    user "root"
    code <<-EOF
   set -e
   if [ ! -d #{node['conda']['dir']}/#{d} ] ; then    # if a new install, mv out envs/libs to keep when upgrading
       mv #{node['conda']['home']}/#{d} #{node['conda']['dir']}
       chown -R #{node['conda']['user']}:#{node['conda']['group']} #{node['conda']['dir']}/#{d}
   else  # this is an upgrade, keep existing installed libs/envs/etc
      rm -rf #{node['conda']['home']}/#{d}
   fi
  EOF
  end
  link "#{node['conda']['home']}/#{d}" do
    owner node['conda']['user']
    group node['conda']['group']
    to "#{node['conda']['dir']}/#{d}"
  end
end

magic_shell_environment 'PATH' do
  value "$PATH:#{node['conda']['base_dir']}/bin"
end


ulimit_domain node['conda']['user'] do
  rule do
    item :nice
    type :hard
    value -10
  end
  rule do
    item :nice
    type :soft
    value -10
  end
end

template "/home/#{node['conda']['user']}/hops-system-environment.yml" do
  source "hops-system-environment.yml.erb"
  user node['conda']['user']
  group node['conda']['group']
  mode 0750
end
