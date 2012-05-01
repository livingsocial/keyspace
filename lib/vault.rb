require 'pathname'
require 'vault/version'

require 'vault/bucket'

module Vault
  def self.bucket_path
    @bucket_path ||= Pathname.new File.expand_path('../../buckets', __FILE__)
  end
end
