Vagrant.configure("2") do |config|
	config.vm.box = "centos/7"
		config.vm.provider "virtualbox" do |v|
		v.memory = 2048
	end

	config.vm.define "CACHE" do |db|
		db.vm.network "private_network", ip: "192.168.56.110"
		db.vm.provision "ansible" do |ansible|
			ansible.playbook = "provisioning.yaml"
			ansible.inventory_path = "hosts"
			ansible.limit = "db"
		end
  end
end
