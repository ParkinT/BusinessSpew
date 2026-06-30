require 'bundler/setup'
Bundler.require(:default)

Object.send(:remove_const, :ActiveRecord) rescue nil

require_relative 'app'

run BusinessSpew::App
