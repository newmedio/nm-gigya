Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name        = 'nm-gigya'
  s.version     = '0.1.21'
  s.date        = '2019-02-07'
  s.summary       = "Gigya API Utility Package"
  s.authors     = ["Jonathan Bartlett", "Tyler Jackson", "Clark Ritchie"]
  s.email       = 'jonathan@newmedio.com'
  s.files       = [
	"lib/gigya/connection.rb",
	"lib/gigya/controller_utils.rb",
	"lib/gigya/session.rb",
	"lib/gigya/user.rb",
	"lib/gigya/extensions.rb",
	"lib/gigya.rb",
  ]
  s.homepage    = "http://www.newmedio.com/"
  s.license       = 'MIT'
  s.require_path  = 'lib'

  s.add_runtime_dependency 'httparty', '~> 0.16.2'
  s.add_runtime_dependency 'jwt', '~> 2.1'
end
