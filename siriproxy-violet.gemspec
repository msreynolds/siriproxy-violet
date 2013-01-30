# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "siriproxy-violet"
  s.version     = "1.0"
  s.authors     = ["Matthew Reynolds, Mountain Labs"]
  s.email       = ["matt@mtnlabs.com"]
  s.homepage    = "mtnlabs.com"
  s.summary     = %q{SiriProxy plugin for controlling the Indigo Automation Server}
  s.description = %q{This plugin can control your Indigo system through voice control phrases issued to SiriProxy}

  s.rubyforge_project = ""

  s.files         = `git ls-files 2> /dev/null`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/* 2> /dev/null`.split("\n")
  s.executables   = `git ls-files -- bin/* 2> /dev/null`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_runtime_dependency "addressable"
  s.add_runtime_dependency "net-http-digest_auth"

end
