require 'sinatra'
require 'bio-publisci'
require 'htmlentities'
include PubliSci::Prov::DSL

get '/test' do
  stream do |out|
    out << "This is -\n"
    sleep 1
    out << " a streaming \n"
    sleep 2
    out << "- message!\n"
  end
end

get '/' do
  agent :publisci, subject: 'http://gsocsemantic.wordpress.com/publisci', type: "software"
  agent :R, subject: "http://r-project.org"
  agent :sciruby, subject: "http://sciruby.com", type: "organization"

  plan :R_steps, subject: "http://example.org/plan/R_steps", steps: "spec/resource/example.Rhistory"

  agent :Will do
    subject "http://gsocsemantic.wordpress.com/me"
    type "person"
    name "Will Strinz"
    on_behalf_of "http://sciruby.com"
  end

  entity :triplified_example, subject: "http://example.org/dataset/ex", generated_by: :triplify

  entity :original do
    generated_by :use_R
    subject "http://example.org/R/ex"
    source "./example.RData"

    has "http://purl.org/dc/terms/title", "original data object"
  end

  activity :triplify do
    subject "http://example.org/activity/triplify"
    generated "http://example.org/dataset/ex"
    associated_with :publisci
    used :original
  end

  activity :use_R do
    subject "http://example.org/activity/use_R"
    generated "http://example.org/R/ex"

    associated_with :R
    associated_with :Will
  end

  coder = HTMLEntities.new
  coder.encode(generate_n3).gsub("\n","<br>").gsub("\t","&nbsp;&nbsp;")
end