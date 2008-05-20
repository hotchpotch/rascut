
require 'rubygems'
require 'logger'
require 'rascut/utils'
require 'json'

class Array
  def uniq_by
    inject({}) do |hash, item|
      hash[yield(item)] ||= item
      hash
    end.values
  end
end


module Rascut
  module Asdoc
    class Data
      class <<
        include Utils
        def asdoc_json
          asdoc_data.to_json
        end

        def asdoc_import_dict
          res = []
          Utils.rascut_db_read do |db|
            db[:asdoc].each do |key, val|
              val.each {|v| 
                next if v[:classname][0..0].match(/[a-z]/)
                res << "#{v[:classname]} #{v[:package]}.#{v[:classname]}"
              }
            end
          end
          res.sort.uniq.join("\n")
        end

        def asdoc_dict
          res = []
          Utils.rascut_db_read do |db|
            db[:asdoc].each do |key, val|
              val.each {|v| 
                res << v[:classname] if v[:classname].length >= 4
                v[:methods].each {|met|
                  res << met[:name] if met[:name].length >= 4
                }
              }
            end
          end
          res.sort.uniq.join("\n")
        end

        def asdoc_data
          classes = []
          packages = []
          methods = []
          Utils.rascut_db_read do |db|
            db[:asdoc].each do |key, val|
              val.each {|v|
                classes << {
                  :classname => v[:classname],
                  :package => v[:package],
                  :asdoc_dir => v[:asdoc_dir]
                }

                packages << {
                  :package => v[:package],
                  :asdoc_dir => v[:asdoc_dir]
                }

                v[:methods].each {|met|
                  met.delete :code
                  met.delete :summary
                  met[:package] = v[:package]
                  met[:classname] = v[:classname]
                  met[:href] = "#{v[:asdoc_dir]}/#{v[:filename]}#{met[:href]}"
                  methods << met
                }
              }
            end
          end

          packages = packages.uniq_by {|s| s.to_a.join('_')}.sort_by {|a| a[:package]}
          classes = classes.uniq_by {|s| s.to_a.join('_')}.sort_by {|a| a[:classname]}
          {
            :methods => methods.sort_by {|a| a[:name]},
            :classes => classes,
            :packages => packages
          }
        end

      end
    end
  end
end

if __FILE__ == $0
  require 'benchmark'
  puts Rascut::Asdoc::Data.asdoc_dict

  #exit
  #p res.select{|i| i[:name].index('draw') == 0 }.length

  #Benchmark.bm do |x|
  #  x.report {
  #    100.times {
  #       p = []
  #       res.select{|i| i[:name].index('draw') == 0 }
  #   }
  #  }
  #  x.report {
  #    100.times {
  #    res.select{|i| i[:name].match(/^draw/) }
  #   }
  #  }
  #  x.report {
  #    100.times {
  #    res.select{|i| i[:name][0..3] == 'draw' }
  #   }
  #  }
  #end
end


