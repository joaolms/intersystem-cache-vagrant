Vagrant.configure("2") do |config|
	config.vm.box = "centos/7"
		config.vm.provider "virtualbox" do |v|
		v.memory = 2048
	end

	config.vm.define "CACHE" do |db|
		db.vm.network "private_network", ip: "192.168.56.110"
		db.vm.provision "shell", inline: "mkdir -p /inst /dados /backup && chown -R vagrant:vagrant /inst /backup"
		# db.vm.provision "file", source: "~/Downloads/Intersystems/2018.1.4/cache-2018.1.4.505.1-lnxrhx64.tar.gz", destination: "/inst/"
		db.vm.provision "file", source: "./vagrant-resources/cacheusers.xml", destination: "/inst/cacheusers.xml"
		db.vm.provision "file", source: "./vagrant-resources/CacheDefault.xml", destination: "/inst/"
		db.vm.provision "shell", path: "./vagrant-resources/cacheDeploy-rhel7.sh", args: "db"
	end
end
