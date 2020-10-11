# (C) 2019~2020 Crafted by Roberto Nogueira
# email : roberto.nogueira@tecnogrupo.com.br.com
# trello: robertonogueira17

Pry.config.pager = true
Pry.config.color = true

# wrap ANSI codes so Readline knows where the prompt ends
def colour(name, text)
  if Pry.color
    "\001#{Pry::Helpers::Text.send name, '{text}'}\002".sub '{text}', "\002#{text}\001"
  else
    text
  end
end

Pry.config.prompt = [
    proc do |object, nest_level, pry|
      prompt  = colour :bright_black, Pry.view_clip(object)
      prompt += ":#{nest_level}" if nest_level > 0
      if defined?(Rails::Console)
        prompt += colour :green, " #{__current_database}"
      end
      prompt += colour :cyan, " > "
    end, proc { |object, nest_level, pry| colour :cyan, "> " }
]

# tell Readline when the window resizes
old_winch = trap 'WINCH' do
  if `stty size` =~ /\A(\d+) (\d+)\n\z/
    Readline.set_screen_size $1.to_i, $2.to_i
  end
  old_winch.call unless old_winch.nil? || old_winch == 'SYSTEM_DEFAULT'
end

# use awesome print for output if available
begin
  require 'amazing_print'
  AmazingPrint.pry!
rescue LoadError => err
  Pry.config.print = Pry::DEFAULT_PRINT
end

# used to print the content tables and models when typed, e.g. accesses, status_types, project..etc
if defined?(Rails::Console)
  def self.method_missing(m, *args, &block)
    class_name = "#{m}".classify.constantize
    if class_name.is_a?(Class) && ActiveRecord::Base.connection.table_exists?("#{m}")
      if args[0].present?
        if tp.config_for(class_name).present?
          tp class_name.where(id: Array(args))
        else
          tp class_name.where(id: Array(args)), class_name.column_names.take(8)
        end
      else
        if tp.config_for(class_name).present?
          tp class_name.limit(100)
        else
          tp class_name.limit(100), class_name.column_names.take(8)
        end
      end
    end
    if class_name.is_a?(Class) && !ActiveRecord::Base.connection.table_exists?("#{m}") && ActiveRecord::Base.connection.table_exists?("#{m}".pluralize)
      if args[0].present?
        class_name.find(args[0])
      else
        puts "#{class_name.count}".cyanish
      end
    end
  end
end


# handle ActiveRecord database and logs
module DBs
  def __exists?
    begin
      ActiveRecord::Base.connection_pool.with_connection(&:active?)
    rescue
      false
    end
  end

  def __current_database
    ActiveRecord::Base.connection.current_database
  end

  def __db(env = ENV['RAILS_ENV'])
    if env == 'development'
      Rails.configuration.database_configuration['development']['database']
    elsif env == 'test'
      Rails.configuration.database_configuration['test']['database']
    end
  end

  def __tables
    ActiveRecord::Base.connection.tables.count
  end

  def __records
    ActiveRecord::Base.connection.tables.map!{|t| t.classify.safe_constantize.count if t.classify.safe_constantize.present?}.compact.inject(:+)
  end

  def __log
    Logger::INFO
  end

  def __log_off
    @old_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = nil
  end

  def __log_on
    ActiveRecord::Base.logger = @old_logger
  end

  def __db_config
    ActiveRecord::Base.connection_config
  end
end

if defined?(Rails::Console)
  include DBs

  __log_on
end
