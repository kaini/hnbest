require "rubygems"
require "bundler"

Bundler.require

require File.dirname(__FILE__) + "/hnbest"
run Sinatra::Application

