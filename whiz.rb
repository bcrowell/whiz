#!/usr/bin/ruby

require 'json'
require 'psych'
require 'yaml'

# usage:
#   whiz.rb verb args
#   whiz.rb parse_hw '{"in_file":"foo.yaml","out_file":"hw.json","book":"lm"}'
#   whiz.rb hw_table '{"in_file":"hw.json","out_file":"hw_table.tex","book":"lm"}'
# args are normally a JSON structure, surrounded by ''

$label_to_num = {}
$has_solution = {} # boolean, $has_solution[[7,3]] for ch. 7, #3

def fatal_error(message)
  $stderr.print "whiz.rb: fatal error: #{message}\n"
  exit(-1)
end


def parse_json_or_die(json)
  begin
    return JSON.parse(json)
  rescue JSON::ParserError
    fatal_error("syntax error in JSON string '#{json}'")
  end
end

# This can read either JSON or YAML (since JSON is a subset of YAML).
def get_yaml_data_from_file(file)
  parsed = begin
    YAML.load(File.open(file))
  rescue ArgumentError => e
    fatal_error("invalid YAML syntax in file #{file}")
  end
  return parsed
end

# returns contents or nil on error; for more detailed error reporting, see slurp_file_with_detailed_error_reporting()
def slurp_file(file)
  x = slurp_file_with_detailed_error_reporting(file)
  return x[0]
end

# returns [contents,nil] normally [nil,error message] otherwise
def slurp_file_with_detailed_error_reporting(file)
  begin
    File.open(file,'r') { |f|
      t = f.gets(nil) # nil means read whole file
      if t.nil? then t='' end # gets returns nil at EOF, which means it returns nil if file is empty
      return [t,nil]
    }
  rescue
    return [nil,"Error opening file #{file} for input: #{$!}."]
  end
end

def get_json_data_from_file_or_die(file)
  r = slurp_file_with_detailed_error_reporting(file)
  if !(r[1].nil?) then fatal_error(r[0]) end
  return parse_json_or_die(r[0])
end

# This can read either JSON or YAML (since JSON is a subset of YAML). If it's JSON, better to use
# the specific JSON routine.
def get_yaml_data_from_file_or_die(file)
  parsed = begin
    YAML.load(File.open(file))
  rescue ArgumentError => e
    fatal_error("invalid YAML syntax in file #{file}")
  end
  return parsed
end

################################################################################################

def read_problems_csv(book)
  File.readlines(find_problems_csv(book)).each { |line|
    if line=~/(.*),(.*),(.*),(.*),(.*)/ then
      b,ch,num,label,soln = [$1,$2.to_i,$3.to_i,$4,$5.to_i]
      if b==book then
        $label_to_num[label] = [ch,num]
        $has_solution[[ch,num]] = (soln==1)
      end
   end
  }
end

def find_problems_csv(book)
  problems_csv = '/home/bcrowell/Documents/writing/books/physics/data/problems.csv'
  if book=='fund' then problems_csv = '/home/bcrowell/Documents/writing/books/fund/problems.csv' end
  return problems_csv
end

################################################################################################

def parse_hw_chunk(chunk)
  result = []
  chunk.gsub(/\s+/,'').split(/;/).each { |g|
    flags = {}
    if g=~/(.*):(.*)/ then
      f,g = [$1,$2]
      f.split('').each {|c| flags[c]=true }
    end
    g = g.split(/,/).map {|x| x.split(/\|/)}
    g.each { |a|
      a.map! { |b|
        parts = ''
        if b=~/(.*)\/(.*)/ then
          b,parts = [$1,$2]
        end
        label = b
        if $label_to_num.has_key?(b) then 
          b=$label_to_num[label]
        else
          b=[-1,-1]
          $stderr.print "warning: name #{label} not found in problems.csv\n"
        end
        b.push(parts)
        b
      }
    }
    result.push([flags,g])
  }
  return result
end

def parse_hw_stream(stream)
  stream['chunks'].map! { |chunk|
    parse_hw_chunk(chunk) # modifies the contents of the data structure, since this is by reference
  }
  return stream
end

def parse_hw(args)
  unless args.has_key?('in_file') then fatal_error("args do not contain in_file key: #{JSON.generate(args)}") end
  a = get_yaml_data_from_file_or_die(args['in_file'])
  b = a.clone

  unless args.has_key?('book') then fatal_error("args do not contain book key: #{JSON.generate(args)}") end
  book = args['book']
  read_problems_csv(book)

  b.map! { |stream|
    parse_hw_stream(stream)
  }

  unless args.has_key?('out_file') then fatal_error("args do not contain out_file key: #{JSON.generate(args)}") end
  File.open(args['out_file'],'w') { |f|
    f.print JSON.pretty_generate(b)
  }
end

def describe_prob_and_parts(p)
  return (p[1].to_s+p[2]).downcase
end

def describe_individualization_group_simple(g)
  if g.length==1 then return g[0][0].to_s+'-'+describe_prob_and_parts(g[0]) end
  all_same_chapter = g.map {|p| p[0]==g[0][0]}.reduce {|a,b| a && b}
  if all_same_chapter then
    return g[0][0].to_s+'('+(g.map {|p| describe_prob_and_parts(p)}.join('|'))+')'
  end
  if p[0]==1 && p[1]==13 then print "==== #{JSON.generate(p)}\n" end
  return '('+(g.map {|p| p[0]+'-'+describe_prob_and_parts(p)}.join('|'))+')'
end

def describe_individualization_group(flags,g)
  s = describe_individualization_group_simple(g)
  if $has_solution[[g[0][0],g[0][1]]] then flags['s']=true end
  flags.keys.each { |f|
    s=s+f unless f=='o'
  }
  return s
end

def hw_table(args)
  unless args.has_key?('in_file') then fatal_error("args do not contain in_file key: #{JSON.generate(args)}") end
  hw = get_json_data_from_file_or_die(args['in_file'])

  unless args.has_key?('book') then fatal_error("args do not contain book key: #{JSON.generate(args)}") end
  book = args['book']
  read_problems_csv(book)

  sets = []
  stream_starts_at_set = 1
  hw.each { |stream|
    stream_starts_at_set = stream_starts_at_set+stream["delay"].to_i
    set_number = stream_starts_at_set
    stream["chunks"].each { |chunk|
      if sets[set_number].nil? then sets[set_number]=[] end
      sets[set_number].push(chunk)
      set_number = set_number+1
    }
  }
  1.upto(sets.length-1) { |set_number|
    if sets[set_number].nil? then sets[set_number]=[] end
  }

  unless args.has_key?('out_file') then fatal_error("args do not contain out_file key: #{JSON.generate(args)}") end
  tex = ''
  tex = tex + <<-'TEX'
         \documentclass{article}
         \usepackage[T1]{fontenc} % http://tex.stackexchange.com/questions/1774/how-to-insert-pipe-symbol-in-latex
         \begin{document}
         TEX
  1.upto(sets.length-1) { |set_number|
    set = sets[set_number]
    tex = tex + "\\noindent{\\textbf{Homework #{set_number}}}\\\\\n"
    count_paper = ''
    count_online = ''
    stuff = [[],[]]
    0.upto(1) { |online|
      set.each { |stream_group|
        stream_group.each { |flag_group|
          flags,probs = flag_group
          is_online = (flags.has_key?("o"))
          if (is_online && online==1) || (!is_online && online==0) then
            probs.each { |individualization_group|
              stuff[online].push(describe_individualization_group(flags,individualization_group))
            }
          end
        }
      }
    }
    tex = tex + <<-"TEX"
      \\begin{tabular}{p{60mm}p{60mm}}
      \\emph{paper} #{count_paper} & \\emph{online} #{count_online} \\\\
      #{stuff[0].join(' ')} & #{stuff[1].join(' ')}
      \\end{tabular}
      TEX
  }
  tex = tex + "\\end{document}\n"
  File.open(args['out_file'],'w') { |f|
    f.print tex
  }
end

################################################################################################


if ARGV.length!=2 then
  fatal_error("illegal arguments: #{ARGV.join(' ')}\nThere should be 2 arguments.\nusage:\n  whiz.rb verb 'json_args'")
end
$verb = ARGV[0]
$args = parse_json_or_die(ARGV[1])

if $verb=="parse_hw" then parse_hw($args); exit(0) end
if $verb=="hw_table" then hw_table($args); exit(0) end
fatal_error("unrecognized verb: $verb")
