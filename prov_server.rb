require 'sinatra'
require "sinatra/reloader" if development?
require 'bio-publisci'
require 'htmlentities'
require 'coffee-script'
use Rack::Logger

helpers do
  def logger
    request.logger
  end

  def input_txt
    <<-EOF
provenance do
  entity :triplified_example

  agent :publisci, subject: 'http://gsocsemantic.wordpress.com/publisci', type: "software"

  activity :triplify do
    generated :triplified_example
    associated_with :publisci
  end
end
    EOF
  end

  def default_query
    <<-EOS
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX prov: <http://www.w3.org/ns/prov#>

SELECT * WHERE{
  ?s ?p ?o
} LIMIT 10
    EOS
  end

  def repos
    settings.repos
  end

  def turtles
    settings.turtles
  end

end

enable :sessions

configure do
  set :repos, {}
  set :turtles, {}
  file = File.new("log.log", 'a+')
  file.sync = true
  use Rack::CommonLogger, file
end

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
  session.clear unless repos[session[:repo_key]]

  if session[:turtle]
    redirect to('/viewit')
  else
    redirect to('/input')
  end
end

get '/input' do
  haml :input
end

post '/input' do
  ev = Class.new{include PubliSci::DSL}.new
  ev.instance_eval(params[:input])
  session[:turtle_key] = Time.now.nsec
  turtles[session[:turtle_key]] = ev.instance_eval 'generate_n3'
  coder = HTMLEntities.new
  turtles[session[:turtle_key]] = coder.encode(turtles[session[:turtle_key]]).gsub("\n","<br>").gsub("\t","&nbsp;&nbsp;")
  session[:repo_key] = Time.now.nsec
  repos[session[:repo_key]] = ev.instance_eval 'to_repository'
  logger.info "new repository #{repos[session[:repo_key]]}, #{Time.now}"
  redirect to('/viewit')
end

get '/viewit' do
  redirect to('/') unless repos[session[:repo_key]]
  if session[:repo_key]
    coder = HTMLEntities.new
    @repo = coder.encode(repos[session[:repo_key]].to_s)
    @ttl = turtles[session[:turtle_key]]
    haml :view_repo
  else
    redirect to('/')
  end
end

get '/query' do
  redirect to('/') unless repos[session[:repo_key]]
  coder = HTMLEntities.new
  @repo = coder.encode(repos[session[:repo_key]].to_s)
  session[:query] ||= default_query
  @query = session[:query]
  # @result = session[:query_result]
  haml :query
end

post '/query' do
  # redirect to('/') unless repos[session[:repo_key]]
  repo = repos[session[:repo_key]]
  coder = HTMLEntities.new
  @repo = coder.encode(repo.to_s)
  @query = params[:query]
  session[:query] = @query
  @result = SPARQL.execute(@query, repo)
  str = '<table border="1">'
  @result.map{|solution|
    str << "<tr>"
    solution.bindings.map{|bind,result|
      str << "<td>" + coder.encode("#{bind}:  #{result.to_s}") + "</td>"
    }
    str << "</tr>"
  }
  str << "</table>"
  @result = str
  # session[:query_result] = @result
  # @query = session[:query]
  haml :query
end

get '/script.js' do
  coffee :script
end
