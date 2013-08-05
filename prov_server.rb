require 'sinatra'
require 'bio-publisci'
require 'htmlentities'
require 'coffee-script'
require "haml-more"

helpers do
  def input_txt
    <<-EOF
entity :triplified_example

agent :publisci, subject: 'http://gsocsemantic.wordpress.com/publisci', type: "software"

activity :triplify do
  generated :triplified_example
  associated_with :publisci
end
    EOF
  end

  def repos
    @@repos ||= {}
  end
end

enable :sessions

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
  ev = PubliSci::Prov::DSL::Singleton.new
  ev.instance_eval(params[:input])
  session[:turtle] = ev.instance_eval 'generate_n3'
  coder = HTMLEntities.new
  session[:turtle] = coder.encode(session[:turtle]).gsub("\n","<br>").gsub("\t","&nbsp;&nbsp;")
  session[:repo_key] = Time.now.nsec
  repos[session[:repo_key]] = ev.instance_eval 'to_repository'
  redirect to('/viewit')
end

get '/viewit' do
  if session[:repo_key]
    @repo = repos[session[:repo_key]]
    @ttl = session[:turtle]
    haml :view_repo
  else
    redirect to('/')
  end
end

get '/script.js' do
  coffee :script
end