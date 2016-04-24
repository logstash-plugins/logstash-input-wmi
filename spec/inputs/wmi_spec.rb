# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/inputs/wmi'

describe LogStash::Inputs::WMI, :windows => true do
  it_behaves_like "an interruptible input plugin" do
    let(:config) { { "query" => "select * from Win32_Process", "interval" => 10 }}
  end
end
