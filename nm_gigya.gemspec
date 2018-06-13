Gem::Specification.new do |s|
  s.name        = 'Gigya API Utilities'
  s.version     = '0.0.1'
  s.date        = '2018-06-13'
  s.summary     = "Utility package for accessing Gigya"
  s.authors     = ["Jonathan Bartlett"]
  s.email       = 'jonathan@newmedio.com'
  s.files       = [
	"lib/gigya/controller_utils.rb",
	"lib/gigya/railtie.rb",
	"lib/gigya.rb",
  ]
  s.homepage    = "http://www.newmedio.com/"
  s.license       = 'Nonstandard'
  s.require_path = 'lib'
  s.add_development_dependency("dotenv")
  s.add_development_dependency("activesupport")
  s.add_dependency('httparty')
  s.add_dependency("jwt")
end
