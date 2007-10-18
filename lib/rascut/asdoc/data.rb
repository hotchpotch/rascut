
require 'rubygems'
require 'logger'
require 'rascut/utils'
require 'json'

module Rascut
  module Asdoc
    class Data
      class <<
        include Utils
        def asdoc_json
          asdoc_data.to_json
        end

        def asdoc_data
          res = []
          Utils.rascut_db_read do |db|
            db[:asdoc].each do |key, val|
              val.each {|v|
                v[:methods].each {|met|
                  met.delete :code
                  met.delete :summary
                  met[:package] = v[:package]
                  met[:classname] = v[:classname]
                  met[:href] = "#{v[:asdoc_dir]}/#{v[:filename]}#{met[:href]}"
                  res << met
                }
              }
            end
          end
          res.sort_by{|a| a[:name]}
        end

      end
    end
  end
end

if __FILE__ == $0
  require 'benchmark'
  res = Rascut::Asdoc::Data.asdoc_data

  p res.select{|i| i[:name].index('draw') == 0 }.length

  Benchmark.bm do |x|
    x.report {
      100.times {
      res.select{|i| i[:name].index('draw') == 0 }
     }
    }
    x.report {
      100.times {
      res.select{|i| i[:name].match(/^draw/) }
     }
    }
    x.report {
      100.times {
      res.select{|i| i[:name][0..3] == 'draw' }
     }
    }
  end
end


