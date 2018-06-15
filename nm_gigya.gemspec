Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name        = 'nm-gigya'
  s.version     = '0.0.5'
  s.date        = '2018-06-13'
  s.summary     = "Utility package for accessing Gigya"
  s.authors     = ["Jonathan Bartlett"]
  s.email       = 'jonathan@newmedio.com'
  s.files       = [
	"lib/gigya/connection.rb",
	"lib/gigya/controller_utils.rb",
	"lib/gigya.rb",
  ]
  s.homepage    = "http://www.newmedio.com/"
  s.license       = 'MIT'
  s.require_path = 'lib'
  s.add_dependency('httparty')
  s.add_dependency("jwt")
end
