#!/usr/bin/ruby

# usage:
#   whiz.rb verb args
#   whiz.rb parse_hw '{"in_file":"foo.yaml","out_file":"hw.json","book":"lm"}'
#   whiz.rb hw_table '{"in_file":"hw.json","out_file":"hw_table.tex","book":"lm"}'
#   whiz.rb points_possible '{"in_file":"hw.json","out_file":"points_possible.csv","book":"lm"}'
#   whiz.rb sets_csv '{"in_file":"hw.json","out_file":"sets.csv","book":"lm","gb_file":"foo.gb","term":"f14"}'
#          gb_file can be null string, for fake run with only Joe Blow on roster
#   whiz.rb roster_csv '{"out_file":"roster.csv","gb_file":"foo.gb"}'
#          gb_file can be null string, for fake run with only Joe Blow on roster
#   whiz.rb self_service_hw_list '{"in_file":"hw.json","out_file":"hw.html","book":"lm",
#                "term":"f14","boilerplate":"foo.html","class_title":"Physics 210","section":"m"}'
#          boilerplate can be null string or name of html file to include at top
#   whiz.rb syllabus '{"tex_file":"syll.tex","out_file_stem":"syll210f14","term":"f14",
#                            "boilerplate_dir":"../../..","class":"210","fruby":"./fruby","section":"m"}'
#   whiz.rb report '{"in_file":"hw.json","out_file":"report","due":"due205f14.csv","sets":"sets.csv",
#                            "reading":"reading.csv","book":"lm"}'
#   optional args for self_service_hw_list:
#     boilerplate_instructions ... file containing html that is displayed when student first hits the page
#   optional args for sets_csv:
#     class ... select only that class; error if some students don't have class set
#   optional args for points_possible and hw_table:
#     ec_if ... list of flags (like 'c') that cause a problem to be counted as extra credit
#   optional args for points_possible and sets_csv:
#     header ... 0 or 1; default=1=output header for csv file; used so I can concatenate 205 & 210 files
#   optional args for points_possible, self_service_hw_list and sets_csv:
#     exclude_if ... list of flags that cause a problem not to be assigned
# args are normally a JSON structure, surrounded by ''

require 'tempfile'
require 'digest/md5'
require 'date'
require 'json'
require 'psych'
require 'yaml'
# require 'open3'

$label_to_num = {}
$num_to_label = {} # $num_to_label[[7,3]]="foo"
$has_solution = {} # boolean, $has_solution[[7,3]] for ch. 7, #3
$problem_assigned_on_set = {} # $problem_assigned_on_set[[7,3]]=12
$files_to_delete = []

$verb = ''

def fatal_error(message)
  $stderr.print "whiz.rb: #{$verb} fatal error: #{message}\n"
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
  if !(r[1].nil?) then fatal_error(r[1]) end
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
  file = find_problems_csv(book)
  File.readlines(file).each { |line|
    if line=~/(.*),(.*),(.*),(.*),(.*)/ then
      b,ch,num,label,soln = [$1,$2.to_i,$3.to_i,$4,$5.to_i]
      if b==book && label!="deleted" then
        if !($label_to_num[label].nil?) then 
          fatal_error("label #{label} is multiply defined in file #{file} for book #{book}")
        end
        $label_to_num[label] = [ch,num]
        if !($num_to_label[[ch,num]].nil?) then
          fatal_error("problem #{ch}-#{num} has two labels defined, #{$num_to_label[[ch,num]]} and #{label}, both for book #{book}")
        end
        $num_to_label[[ch,num]] = label
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

def describe_prob_and_parts_with_flags(p,flags,format)
  return (p[1].to_s+p[2]).downcase+describe_flags(flags,format)
end

def chapter_of_individualization_group(g)
  all_same_chapter = g.map {|p| p[0]==g[0][0]}.reduce {|a,b| a && b}
  if !all_same_chapter then return nil end
  return g[0][0]
end

def describe_individualization_group_simple(g)
  if g.length==1 then return g[0][0].to_s+'-'+describe_prob_and_parts(g[0]) end
  all_same_chapter = !(chapter_of_individualization_group(g).nil?)
  if all_same_chapter then
    u = g.clone
    u = u.sort {|a,b| a[1].to_i <=> b[1].to_i}
    return g[0][0].to_s+'('+(u.map {|p| describe_prob_and_parts(p)}.join('|'))+')'
  end
  if p[0]==1 && p[1]==13 then print "==== #{JSON.generate(p)}\n" end
  return '('+(g.map {|p| p[0]+'-'+describe_prob_and_parts(p)}.join('|'))+')'
end

# format can be plain,tex,html
def describe_flags(flags,format)
  d = ''
  flags.keys.each { |f|
    if f=='c' then
      if format=='tex' then f="$\\int$" end
      if format=='plain' then f="(calculus)" end
      if format=='html' then f="&int;" end
    end
    d=d+f unless f=='o'
  }
  return d
end

# format can be plain,tex,html
def describe_individualization_group(flags,g,format)
  s = describe_individualization_group_simple(g)
  fl = flags.clone # don't modify flags for other members of the flag group
  if $has_solution[[g[0][0],g[0][1]]] then fl['s']=true end
  s = s + describe_flags(flags,format)
  return s
end

def lowest_number_in_individualization_group(g)
  l = 9999
  g.each { |p|
    if p[1]<l then l=p[1] end
  }
  return l
end

def spaceship_individualization_group(g1,g2)
  c1 = chapter_of_individualization_group(g1)
  c2 = chapter_of_individualization_group(g2)
  if c1.nil? || c2.nil? then # mixture of different chapters
    return (describe_individualization_group_simple(g1) <=> describe_individualization_group_simple(g2))
    # shouldn't happen, but if it does, do something half-way reasonable using string comparison
  end
  if c1!=c2 then return c1 <=> c2 end
  return lowest_number_in_individualization_group(g1) <=> lowest_number_in_individualization_group(g2)
end

# converts json streams to problem sets
# has side-effect of reading problems.csv file and filling in $problem_assigned_on_set
def hw_to_sets(hw,book) 
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

  read_problems_csv(book)

  1.upto(sets.length-1) { |set_number|
    sets[set_number].each { |chunk|
      chunk.each { |fg|
        flags,probs = fg
        probs.each { |g|
          g.each { |p|
            k = [p[0],p[1]]
            label = $num_to_label[k]
            if $problem_assigned_on_set[k].nil?
              $problem_assigned_on_set[k] = set_number
            else
              if p[2].nil? || p[2]=='' then
                fatal_error("problem #{p[0]}-#{p[1]}, #{label}, assigned on both hw #{$problem_assigned_on_set[k]} and hw #{set_number}, and no specific parts were given on the second hw")
              end
            end
          }
        }
      }
    }
  }

  return sets
end

# sets = output of hw_to_sets
# return value is array of lists of entries like this:
#   [nil,"note associated with a particular hw"]
#   [[3,27],"also associated specifically with problem 3-27"]
def assign_notes_to_sets(sets,hw,book)
  notes = []
  stream_starts_at_set = 1
  hw.each { |stream|
    stream_starts_at_set = stream_starts_at_set+stream["delay"].to_i
    if !(stream["notes"].nil?) then
      stream["notes"].each { |t,text|
        t = t.to_s
        p = nil
        if t=~/\A(\d+)\Z/ then
          t = $1.to_i
          s = stream_starts_at_set+t
        else
          if !($label_to_num.has_key?(t)) then
            fatal_error("note is given for problem #{t}, but no such label is defined; text of note is #{text}")
          end
          ch,num = $label_to_num[t]
          p = [ch,num]
          s = $problem_assigned_on_set[p]
          text.gsub!(/\$\$/) {"#{ch}-#{num}"}
        end
        if notes[s].nil? then notes[s]=[] end
        notes[s].push([p,text])
      }
    end                                                                              
  }
  1.upto(sets.length-1) { |set_number|
    if notes[set_number].nil? then notes[set_number]=[] end
  }
  return notes
end

# sets = output of hw_to_sets
# returns array of strings consisting of the labels of the streams from the yaml file
def assign_starts_of_streams_to_sets(sets,hw)
  stream_labels = []
  stream_starts_at_set = 1
  hw.each { |stream|
    stream_starts_at_set = stream_starts_at_set+stream["delay"].to_i
    if stream_labels[stream_starts_at_set].nil? then
      stream_labels[stream_starts_at_set]=stream["stream"]
    else
      stream_labels[stream_starts_at_set] = stream_labels[stream_starts_at_set]+';'+stream["stream"]
    end
  }
  1.upto(sets.length-1) { |set_number|
    if stream_labels[set_number].nil? then stream_labels[set_number]='' end
    #print "=== #{set_number}->#{stream_labels[set_number]}\n"
  }
  return stream_labels
end

def hw_table(args)
  unless args.has_key?('in_file') then fatal_error("args do not contain in_file key: #{JSON.generate(args)}") end
  hw = get_json_data_from_file_or_die(args['in_file'])
  unless args.has_key?('book') then fatal_error("args do not contain book key: #{JSON.generate(args)}") end
  book = args['book']
  sets = hw_to_sets(hw,book)

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
    c = points_possible_on_set(set,args)
    count_paper = c[[false,false]].to_s+"+"+c[[false,true]].to_s
    count_online = c[[true,false]].to_s+"+"+c[[true,true]].to_s
    stuff = [[],[]]
    0.upto(1) { |online|
      victims = []
      set.each { |stream_group|
        stream_group.each { |flag_group|
          flags,probs = flag_group
          is_online = (flags.has_key?("o"))
          if (is_online && online==1) || (!is_online && online==0) then
            probs.each { |individualization_group|
              victims.push([flags,individualization_group])
            }
          end
        }
      } # end loop over stream groups
      victims.sort {|u,v| spaceship_individualization_group(u[1],v[1])}.each { |v|
        flags,individualization_group = v
        stuff[online].push(describe_individualization_group(flags,individualization_group,'tex'))
      }
    } # end loop over paper and online
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

# returns a hash whose keys are students' database keys, and whose
# records are hashes with the keys last, first, class, id_string, and id_int
# if filename is null string, returns fake roster with only blow_joe, id="0", class="210"
def get_roster_from_opengrade(gb)
  if gb=='' then
    return {"blow_joe"=>{"last"=>"Blow","first"=>"Joe","class"=>"210","id_string"=>"0","id_int"=>"0"}}
  end
  result = {}
  get_json_data_from_file_or_die(gb)['data']['roster'].each { |key,data|
    first = ''
    last = key
    if key=~/(.*)_(.*)/ then last,first=[$1.capitalize,$2.capitalize] end
    if data.has_key?('last') then last=data['last'] end
    if data.has_key?('first') then last=data['first'] end
    id_string = ''
    id_int = 0
    if data.has_key?('id') then id_string=data['id']; id_int=data['id'].to_i end
    cl = ''
    if data.has_key?('class') then cl=data['class'] end
    result[key] = {'last'=>last, 'first'=>first, 'class'=>cl, 'id_string'=>id_string, 'id_int'=>id_int }
  }
  return result
end

# don't use this for tex output if an integral sign is desired for 'c' flag
def flags_to_string(f)
  result = ''
  f.each { |key,value|
    if value then result=result+key end
  }
  return result
end

# Returns a number from 0 to n-1, where n is the length of the array probs.
# Result depends on order of problems; don't worry about sorting this so it's more canonical, since that
#             would be a mess to do correctly and would give no benefits.
# This is also implemented in javascript code, in a function of the same name, embedded in whiz.eb.
# Student ID is treated as a string, so don't convert it to int before passing it in (would lose leading zeroes).
# It doesn't matter whether year is passed as fixnum or string, because it gets converted to fixnum.
def select_using_hash(chapter,probs,year,semester,student_id)
  # year = 2014, etc.; semester = "s" or "f"
  chapter = chapter.to_s
  year = year.to_i
  semester = semester.to_s
  student_id = student_id.to_s
  # figure out an integer for the semester, counting from spring 2014 = 0
  s = (year-2014)*2;
  if semester=="f" then s=s+1 end
  x = student_id+","+chapter+","+probs.join(":")
  hash = md5_hash_hex(x); # 32 hex digits
  hex4 = hash.to_s[-4..-1]
  k = hex4.to_i(16) # convert hex string to fixnum
  k = k+s; # if a student is repeating the course, cycle through the problems, don't assign same one
  n = probs.length;
  if x=='0,2,5:7' then print "x=#{x}, hash=#{hash}, hex4=#{hex4}, k=#{k}, s=#{s}, n=#{n}, k%n=#{k%n}\n" end # qwe
  return k%n;
end

# returns a 32-digit hex string
def md5_hash_hex(x)
  h = Digest::MD5.new
  h << x
  return h.to_s # to_s method gives the result in hex
end

def roster_csv(args)
  unless args.has_key?('gb_file') then fatal_error("args do not contain gb_file key: #{JSON.generate(args)}") end
  roster = get_roster_from_opengrade(args['gb_file']) # last, first, class, id_string, and id_int
  unless args.has_key?('out_file') then fatal_error("args do not contain out_file key: #{JSON.generate(args)}") end
  csv = ''
  roster.keys.sort.each { |student| # FIXME -- sort won't always be right, because based on key, not last/first
    d = roster[student]
    csv = csv + "#{student},\"#{d['last']}\",\"#{d['first']}\",#{d['class']}\n"
  }  
  File.open(args['out_file'],'w') { |f|
    f.print csv
  }
end

# writes a csv file like set,book,ch,num,parts,flags,chunk,student
# if args['gb_file'] is null string, makes fake roster with only blow_joe
# book=1 always; nowadays only one book in xml file; OpenGrade wants a book number, which corresponds to a <toc> in the xml file
def sets_csv(args)
  unless args.has_key?('in_file') then fatal_error("args do not contain in_file key: #{JSON.generate(args)}") end
  hw = get_json_data_from_file_or_die(args['in_file'])
  unless args.has_key?('book') then fatal_error("args do not contain book key: #{JSON.generate(args)}") end
  book = args['book']
  sets = hw_to_sets(hw,book)
  unless args.has_key?('gb_file') then fatal_error("args do not contain gb_file key: #{JSON.generate(args)}") end
  roster = get_roster_from_opengrade(args['gb_file']) # last, first, class, id_string, and id_int
  unless args.has_key?('term') then fatal_error("args do not contain term key: #{JSON.generate(args)}") end
  semester,year = parse_term(args['term'])

  unless args.has_key?('out_file') then fatal_error("args do not contain out_file key: #{JSON.generate(args)}") end
  csv = ''
  csv = "set,book,ch,num,parts,flags,chunk,student\n" unless args.has_key?('header') && args['header']==0
  stuff = []
  1.upto(sets.length-1) { |set_number|
    stuff[set_number] = []
    set = sets[set_number]
    victims = []
    set.each { |stream_group|
      stream_group.each { |flag_group|
        flags,probs = flag_group
        probs.each { |individualization_group|
          victims.push([flags,individualization_group])
        }
      }
    } # end loop over stream groups
    victims.sort {|u,v| spaceship_individualization_group(u[1],v[1])}.each { |v|
      flags,individualization_group = v
      stuff[set_number].push([flags,individualization_group])
    }
  }
  only_class = args['class'] # can be nil
  roster.keys.sort.each { |student| # sort won't always be right, because based on key, not last/first, but we don't care
    if !(only_class.nil?) && (roster[student]["class"].nil? || roster[student]["class"]=='') then
      fatal_error("class not set in gradebook file for #{student}")
    end
    if only_class.nil? || roster[student]["class"]==only_class then
      student_id = roster[student]["id_string"]
      1.upto(sets.length-1) { |set_number|
        stuff[set_number].each { |fg|
          flags,individualization_group = fg
          probs = []
          individualization_group.each { |p| probs.push(p[1])}
          chapter = individualization_group[0][0]
          i = select_using_hash(chapter,probs,year,semester,student_id)
          p = individualization_group[i]
          parts = ''
          if !(p[2].nil?) then parts = p[2].downcase end
          excluded = flags_contain_letter_in_string(flags,args['exclude_if'])
          f = flags_to_string(flags)
          # see comments above function for why book is always 1
          csv = csv + "#{set_number},1,#{p[0]},#{p[1]},#{parts},#{f},,#{student}\n" unless excluded
          if p[0]<0 || p[1]<0 then fatal_error("problem set #{set_number} has illegal ch,num=#{p[0]},#{p[1]}#") end
        }
      }
    end
  }
  File.open(args['out_file'],'w') { |f|
    f.print csv
  }
end

def flags_contain_letter_in_string(flags,s)
  if s.nil? || s=='' then return false end
  a = s.split('') # array of characters
  flags.keys.each { |f|
    if a.include?(f) then return true end
  }
  return false
end

# used by hw_table() and points_possible_to_csv()
# returns a hash c that can be indexed into like c[[online,extra_credit]],
#       where online and extra_credit are booleans
def points_possible_on_set(set,args)
  c = {}
  [true,false].each { |online|
    [true,false].each { |extra_credit|
      c[[online,extra_credit]] = 0
      set.each { |stream_group|
        stream_group.each { |flag_group|
          flags,probs = flag_group
          is_online = (flags.has_key?("o"))
          is_extra_credit = (flags.has_key?("*")) || flags_contain_letter_in_string(flags,args['ec_if'])
          excluded = flags_contain_letter_in_string(flags,args['exclude_if'])
          if is_online==online && is_extra_credit==extra_credit && !excluded then
            probs.each { |g| # g is individualization group
              c[[online,extra_credit]] += 1 unless $has_solution[[g[0][0],g[0][1]]]
            }
          end
        }
      } # end loop over stream groups
    }
  }
  return c
end

def points_possible_to_csv(args)
  unless args.has_key?('in_file') then fatal_error("args do not contain in_file key: #{JSON.generate(args)}") end
  hw = get_json_data_from_file_or_die(args['in_file'])
  unless args.has_key?('book') then fatal_error("args do not contain book key: #{JSON.generate(args)}") end
  book = args['book']
  sets = hw_to_sets(hw,book)

  unless args.has_key?('out_file') then fatal_error("args do not contain out_file key: #{JSON.generate(args)}") end

  csv = ''
  csv = "set,paper_or_online,pts,ec\n" unless args.has_key?('header') && args['header']==0
  1.upto(sets.length-1) { |set_number|
    set = sets[set_number]
    c = points_possible_on_set(set,args)
    ['p','o'].each { |t|
      csv = csv + "#{set_number},#{t},#{c[[(t=='o'),false]]},#{c[[(t=='o'),true]]}\n"
    }
  }
  File.open(args['out_file'],'w') { |f|
    f.print csv
  }
end

# http://stackoverflow.com/questions/1655769/fastest-md5-implementation-in-javascript
# licensing unknown
# tested as follows:
# $ perl -e "use Digest::MD5 qw(md5_hex); print md5_hex('73')"
# d2ddea18f00665ce8623e36bd4e3c7c5
def myers_md5_implementation
  return <<'JS'
// Joseph Myers' implementation of MD5 in JS
// http://www.myersdaily.org/joseph/javascript/md5-text.html
function md5cycle(x, k) {
var a = x[0], b = x[1], c = x[2], d = x[3];

a = ff(a, b, c, d, k[0], 7, -680876936);
d = ff(d, a, b, c, k[1], 12, -389564586);
c = ff(c, d, a, b, k[2], 17,  606105819);
b = ff(b, c, d, a, k[3], 22, -1044525330);
a = ff(a, b, c, d, k[4], 7, -176418897);
d = ff(d, a, b, c, k[5], 12,  1200080426);
c = ff(c, d, a, b, k[6], 17, -1473231341);
b = ff(b, c, d, a, k[7], 22, -45705983);
a = ff(a, b, c, d, k[8], 7,  1770035416);
d = ff(d, a, b, c, k[9], 12, -1958414417);
c = ff(c, d, a, b, k[10], 17, -42063);
b = ff(b, c, d, a, k[11], 22, -1990404162);
a = ff(a, b, c, d, k[12], 7,  1804603682);
d = ff(d, a, b, c, k[13], 12, -40341101);
c = ff(c, d, a, b, k[14], 17, -1502002290);
b = ff(b, c, d, a, k[15], 22,  1236535329);

a = gg(a, b, c, d, k[1], 5, -165796510);
d = gg(d, a, b, c, k[6], 9, -1069501632);
c = gg(c, d, a, b, k[11], 14,  643717713);
b = gg(b, c, d, a, k[0], 20, -373897302);
a = gg(a, b, c, d, k[5], 5, -701558691);
d = gg(d, a, b, c, k[10], 9,  38016083);
c = gg(c, d, a, b, k[15], 14, -660478335);
b = gg(b, c, d, a, k[4], 20, -405537848);
a = gg(a, b, c, d, k[9], 5,  568446438);
d = gg(d, a, b, c, k[14], 9, -1019803690);
c = gg(c, d, a, b, k[3], 14, -187363961);
b = gg(b, c, d, a, k[8], 20,  1163531501);
a = gg(a, b, c, d, k[13], 5, -1444681467);
d = gg(d, a, b, c, k[2], 9, -51403784);
c = gg(c, d, a, b, k[7], 14,  1735328473);
b = gg(b, c, d, a, k[12], 20, -1926607734);

a = hh(a, b, c, d, k[5], 4, -378558);
d = hh(d, a, b, c, k[8], 11, -2022574463);
c = hh(c, d, a, b, k[11], 16,  1839030562);
b = hh(b, c, d, a, k[14], 23, -35309556);
a = hh(a, b, c, d, k[1], 4, -1530992060);
d = hh(d, a, b, c, k[4], 11,  1272893353);
c = hh(c, d, a, b, k[7], 16, -155497632);
b = hh(b, c, d, a, k[10], 23, -1094730640);
a = hh(a, b, c, d, k[13], 4,  681279174);
d = hh(d, a, b, c, k[0], 11, -358537222);
c = hh(c, d, a, b, k[3], 16, -722521979);
b = hh(b, c, d, a, k[6], 23,  76029189);
a = hh(a, b, c, d, k[9], 4, -640364487);
d = hh(d, a, b, c, k[12], 11, -421815835);
c = hh(c, d, a, b, k[15], 16,  530742520);
b = hh(b, c, d, a, k[2], 23, -995338651);

a = ii(a, b, c, d, k[0], 6, -198630844);
d = ii(d, a, b, c, k[7], 10,  1126891415);
c = ii(c, d, a, b, k[14], 15, -1416354905);
b = ii(b, c, d, a, k[5], 21, -57434055);
a = ii(a, b, c, d, k[12], 6,  1700485571);
d = ii(d, a, b, c, k[3], 10, -1894986606);
c = ii(c, d, a, b, k[10], 15, -1051523);
b = ii(b, c, d, a, k[1], 21, -2054922799);
a = ii(a, b, c, d, k[8], 6,  1873313359);
d = ii(d, a, b, c, k[15], 10, -30611744);
c = ii(c, d, a, b, k[6], 15, -1560198380);
b = ii(b, c, d, a, k[13], 21,  1309151649);
a = ii(a, b, c, d, k[4], 6, -145523070);
d = ii(d, a, b, c, k[11], 10, -1120210379);
c = ii(c, d, a, b, k[2], 15,  718787259);
b = ii(b, c, d, a, k[9], 21, -343485551);

x[0] = add32(a, x[0]);
x[1] = add32(b, x[1]);
x[2] = add32(c, x[2]);
x[3] = add32(d, x[3]);
}

function cmn(q, a, b, x, s, t) {
a = add32(add32(a, q), add32(x, t));
return add32((a << s) | (a >>> (32 - s)), b);
}

function ff(a, b, c, d, x, s, t) {
return cmn((b & c) | ((~b) & d), a, b, x, s, t);
}

function gg(a, b, c, d, x, s, t) {
return cmn((b & d) | (c & (~d)), a, b, x, s, t);
}

function hh(a, b, c, d, x, s, t) {
return cmn(b ^ c ^ d, a, b, x, s, t);
}

function ii(a, b, c, d, x, s, t) {
return cmn(c ^ (b | (~d)), a, b, x, s, t);
}

function md51(s) {
txt = '';
var n = s.length,
state = [1732584193, -271733879, -1732584194, 271733878], i;
for (i=64; i<=s.length; i+=64) {
md5cycle(state, md5blk(s.substring(i-64, i)));
}
s = s.substring(i-64);
var tail = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
for (i=0; i<s.length; i++)
tail[i>>2] |= s.charCodeAt(i) << ((i%4) << 3);
tail[i>>2] |= 0x80 << ((i%4) << 3);
if (i > 55) {
md5cycle(state, tail);
for (i=0; i<16; i++) tail[i] = 0;
}
tail[14] = n*8;
md5cycle(state, tail);
return state;
}

/* there needs to be support for Unicode here,
 * unless we pretend that we can redefine the MD-5
 * algorithm for multi-byte characters (perhaps
 * by adding every four 16-bit characters and
 * shortening the sum to 32 bits). Otherwise
 * I suggest performing MD-5 as if every character
 * was two bytes--e.g., 0040 0025 = @%--but then
 * how will an ordinary MD-5 sum be matched?
 * There is no way to standardize text to something
 * like UTF-8 before transformation; speed cost is
 * utterly prohibitive. The JavaScript standard
 * itself needs to look at this: it should start
 * providing access to strings as preformed UTF-8
 * 8-bit unsigned value arrays.
 */
function md5blk(s) { /* I figured global was faster.   */
var md5blks = [], i; /* Andy King said do it this way. */
for (i=0; i<64; i+=4) {
md5blks[i>>2] = s.charCodeAt(i)
+ (s.charCodeAt(i+1) << 8)
+ (s.charCodeAt(i+2) << 16)
+ (s.charCodeAt(i+3) << 24);
}
return md5blks;
}

var hex_chr = '0123456789abcdef'.split('');

function rhex(n)
{
var s='', j=0;
for(; j<4; j++)
s += hex_chr[(n >> (j * 8 + 4)) & 0x0F]
+ hex_chr[(n >> (j * 8)) & 0x0F];
return s;
}

function hex(x) {
for (var i=0; i<x.length; i++)
x[i] = rhex(x[i]);
return x.join('');
}

function md5(s) {
return hex(md51(s));
}

/* this function is much faster,
so if possible we use it. Some IEs
are the only ones I know of that
need the idiotic second function,
generated by an if clause.  */

function add32(a, b) {
return (a + b) & 0xFFFFFFFF;
}

if (md5('hello') != '5d41402abc4b2a76b9719d911017c592') {
function add32(x, y) {
var lsw = (x & 0xFFFF) + (y & 0xFFFF),
msw = (x >> 16) + (y >> 16) + (lsw >> 16);
return (msw << 16) | (lsw & 0xFFFF);
}
}
JS
end

def parse_term(term)
  if term=~/\A([sf])(\d\d)\Z/ then
    semester,year = $1,$2.to_i
    year = year+2000
  else
    fatal_error("term '#{term}' is not formatted like f14")
  end
  return [semester,year]
end

def self_service_hw_list(args)
  unless args.has_key?('in_file') then fatal_error("args do not contain in_file key: #{JSON.generate(args)}") end
  hw = get_json_data_from_file_or_die(args['in_file'])
  unless args.has_key?('book') then fatal_error("args do not contain book key: #{JSON.generate(args)}") end
  book = args['book']
  sets = hw_to_sets(hw,book)
  notes = assign_notes_to_sets(sets,hw,book)
  unless args.has_key?('term') then fatal_error("args do not contain term key: #{JSON.generate(args)}") end
  semester,year = parse_term(args['term'])
  section = require_arg(args,'section')
  unless args.has_key?('boilerplate') then fatal_error("args do not contain boilerplate key: #{JSON.generate(args)}") end
  boilerplate = args['boilerplate']
  if boilerplate!="" then
    b=slurp_file(boilerplate)
    if b.nil? then fatal_error("error reading boilerplate file #{boilerplate}") end
    boilerplate = b
  end
  boilerplate_instructions = ''
  if args.has_key?('boilerplate_instructions') then
    boilerplate_instructions = args['boilerplate_instructions']
    b=slurp_file(boilerplate_instructions)
    if b.nil? then fatal_error("error reading boilerplate file #{boilerplate_instructions}") end
    boilerplate_instructions = b
  end
  unless args.has_key?('class_title') then fatal_error("args do not contain class_title key: #{JSON.generate(args)}") end
  class_title = args['class_title']
  if section=='m' then class_title=class_title+", Mon-Wed section" end
  if section=='t' then class_title=class_title+", Tue-Thu section" end

  unless args.has_key?('out_file') then fatal_error("args do not contain out_file key: #{JSON.generate(args)}") end
  title = "Homework Assignments for #{class_title}, #{semester}#{year}"

  d = [];
  d.push(['string',boilerplate]);
  1.upto(sets.length-1) { |set_number|
    set = sets[set_number]
    d.push(['string',"<h2>Homework #{set_number}</h2>\n"]);
    if !(notes[set_number].nil?) then
      notes[set_number].each { |n|
        prob,note = n
        if prob.nil?
          d.push(['string',"  <p>"+note+"</p>\n"])
        else
          d.push(['conditional',"  <p>"+note+"</p>\n",prob])
        end
      }
    end
    0.upto(1) { |online|
      if online==0 then u="online" else u="paper" end
      d.push(['string',"<p><i>#{u}</i>: "])
      victims = []
      set.each { |stream_group|
        stream_group.each { |flag_group|
          flags,probs = flag_group
          is_online = (flags.has_key?("o"))
          if (is_online && online==1) || (!is_online && online==0) then
            excluded = flags_contain_letter_in_string(flags,args['exclude_if'])
            if !excluded then
              probs.each { |individualization_group|
                victims.push([flags,individualization_group])
              }
            end
          end
        }
      } # end loop over stream groups
      stuff = []
      victims.sort {|u,v| spaceship_individualization_group(u[1],v[1])}.each { |v|
        flags,individualization_group = v
        if individualization_group.length==1 then
          stuff.push(describe_individualization_group(flags,individualization_group,'html'))
          d.push(['assigned',individualization_group[0][0],individualization_group[0][1]])
        else
          chapter = individualization_group[0][0]
          pp = []
          description = []
          individualization_group.each { |p|
            pp.push(p[1])
            dd = p[0].to_s+"-"+describe_prob_and_parts_with_flags(p,flags,'html')
            description.push(dd)
          }
          stuff.push({"chapter"=>chapter,"year"=>year,"semester"=>semester,"probs"=>pp,
                        "description"=>description})
        end
      }
      if stuff.length==0 then 
        d.push(['string','none'])
      else
        stuff.each { |x|
          if x.class.to_s=="String" then
            d.push(['string',x+" "])
          else
            d.push(['indiv',x])
          end
        }
      end
      d.push(['string',"</p>"])
    } # end loop over paper and online
  } # end loop over sets
  
  js = <<-"JS"
    #{myers_md5_implementation}
    function the_hw(student_id) {
      hw_data = #{JSON.generate(d)};
      var html = "";
      // --------- figure out which problems were assigned
      var assigned = {};
      for (var i=0; i<hw_data.length; i++) {
        t = hw_data[i][0];
        x = hw_data[i][1];
        if (t==='assigned') {
          assigned[String(x)+"-"+String(hw_data[i][2])] = 1;
        }
        if (t==='indiv') {
          chapter = x["chapter"]; year = x["year"]; semester = x["semester"]; probs = x["probs"];
          var m = select_using_hash(chapter,probs,year,semester,student_id);
          var p = probs[m];
          assigned[String(chapter)+"-"+String(p)] = 1;
        }
      }
      // --------- generate output
      for (var i=0; i<hw_data.length; i++) {
        t = hw_data[i][0];
        x = hw_data[i][1];
        if (t==='string') { html = html + x; }
        if (t==='conditional') {
          var p = hw_data[i][2];
          var ch = p[0];
          var num = p[1];
          var k = String(ch)+"-"+String(num);
          if (assigned[k]==1) {
            html = html +x;
          }
        }
        if (t==='indiv') {
          chapter = x["chapter"]; year = x["year"]; semester = x["semester"]; probs = x["probs"];
          description = x["description"];
          var m = select_using_hash(chapter,probs,year,semester,student_id);
          //html = html + "m="+String(m)+" ";
          html = html + description[m]+" ";
        }
      }
      return html;
    }
    // Returns a number from 0 to n-1, where n is the length of the array probs.
    // Result depends on order of problems; don't worry about sorting this so it's more canonical, since that
    //         would be a mess to do correctly and would give no benefits.
    // This is also implemented in ruby in a function of the same name in whiz.rb.
    function select_using_hash(chapter,probs,year,semester,student_id) {
      // year = 2014, etc.
      // semester = "s" or "f"
      chapter = String(chapter);
      year = Number(year); // integer such as 2014
      semester = String(semester);
      student_id = String(student_id);
      // figure out an integer for the semester, counting from spring 2014 = 0
      var s = (year-2014)*2;
      if (semester==="f") {s=s+1;}
      var x = student_id+","+chapter+","+probs.join(":");
      var hash = md5(x); // 32 hex digits
      hex4 = hash.substring(28,32); // extracts 28..31
      k = parseInt(hex4,16);
      k = k+s; // if a student is repeating the course, cycle through the problems, don't assign same one
      n = probs.length;
      // if (x==='0,2,5:7') { debug("x="+x+" hash="+hash+" hex4="+hex4+" k="+k+" s="+s+" n="+n)  }
      return k%n;
    }
    function debug(s) {
      var p = document.getElementById("debug");
      p.innerHTML = p.innerHTML+s;
    }
    function calculate() {
      var p = document.getElementById("output");
      var student_id = document.getElementById("student_id").value;
      var result = "";
      result = result + "<h1>Your Homework for #{class_title}, #{semester}#{year}</h2><p>This was generated for student ID "+student_id+". Please print it out.</p>";
      var re = new RegExp("^[0-9]{8,8}$");
      if (!(re.test(student_id))) {
        result = result + "<p>******!!!!!!!! WARNING -- The student ID you've entered is not a possible Fullerton College student ID. A student ID should consist of exactly 8 digits. Don't omit leading zeroes. !!!!!!!********</p>"
      }
      result = result + the_hw(student_id);
      result = result + "<p>Assignments defined #{DateTime.now.strftime "%m-%d-%Y"} for term #{semester}#{year}.</p>";
      p.innerHTML = result;
    }
    function clear_output() {
      document.getElementById("output").innerHTML="";
    }
    JS
  html = <<-"HTML"
    <!doctype html>
    <html lang="en">
      <head><meta charset="utf-8"><title>#{title}</title></head>
      <body>
        <form name="myform">
          <p>
            Read the information below, then enter your student ID:
                   <input type="text" name="student_id" id="student_id">
            <input type="button" value="Enter" onclick="calculate()">
          </p>
        </form>
        <div id="output"><h1>#{title}</h1>#{boilerplate_instructions}</div>
        <p id="debug"></p>
        <script>#{js}</script>
           </body>
    </html>
    HTML
  File.open(args['out_file'],'w') { |f|
    f.print html
  }
end

def require_arg(args,name)
  unless args.has_key?(name) then fatal_error("args do not contain #{name} key: #{JSON.generate(args)}") end
  return args[name]
end

# execute a shell command
# normal use: shell_without_output(c,false,false)
# normal return is [true]
# on error, return value is [false,error message]
def shell_without_capturing_output(c,display,dry_run)
  if display then $stderr.print c+"\n" end
  r = system(c) unless dry_run
  if r.nil? then
    return [false,$?]
  else
    return [true]
  end
  # for capturing output: http://stackoverflow.com/a/5970819/1142217
  # stdin, stdout, stderr, wait_thr = Open3.popen3('usermod', '-p', @options['shadow'], @options['username'])
  # stdout.gets(nil)
  # stderr.gets(nil)
  # exit_code = wait_thr.value
end

# returns a file, so you can do f.write, etc.
def temp_file
  f = Tempfile.new('')
  $files_to_delete.push(f.path)
  return f
end

def syllabus(args)
  tex_file = require_arg(args,'tex_file') # syll.tex
  out_file_stem = require_arg(args,'out_file_stem')
  term = require_arg(args,'term')
  boilerplate_dir = require_arg(args,'boilerplate_dir')
  cl = require_arg(args,'class') # 205, 210, ...
  fruby = require_arg(args,'fruby')
  section = require_arg(args,'section')
  f = temp_file
  f.write("<% $semester=\"#{term}\";  $whichclass=\"#{cl}\" ; $section=\"#{section}\"; $boilerplate=\"#{boilerplate_dir}\" %>")
  f.write(slurp_file(tex_file))
  g = out_file_stem+".tex";
  shell_without_capturing_output("#{fruby} #{f.path} >#{g}",false,false)
  1.upto(2) { |i|
    shell_without_capturing_output("pdflatex -interaction=nonstopmode #{g} >err",false,false)
  }
end

def report(args)
  book = require_arg(args,'book')
  hw = get_json_data_from_file_or_die(require_arg(args,'in_file'))
  sets = hw_to_sets(hw,book)
  stream_labels = assign_starts_of_streams_to_sets(sets,hw) # qwe
  out_file = require_arg(args,'out_file')
  due = require_arg(args,'due')
  sets = require_arg(args,'sets')
  reading = require_arg(args,'reading')
  date_to_meeting = {}
  meeting_to_date = []
  meeting_to_reading = []
  meeting_to_hw = []
  hw_to_meeting = []
  ch_to_meeting = [] # earliest meeting at which hw from this ch was assigned
  meeting_to_ch = [] # inverse of ch_to_meeting
  n_hw_in_syll = 0
  n_hw_defined = 0
  m = 1
  n_meetings = 0
  File.readlines(reading).each { |line|
    unless line=~/(.*),"(.*)"/ then fatal_error("illegal line in #{reading}: #{line}") end
    date,ch = [$1,$2]
    meeting_to_date[m] = date
    date_to_meeting[date] = m
    meeting_to_reading[m] = ch
    meeting_to_ch[m] = nil
    n_meetings = m
    m=m+1
  }
  File.readlines(due).each { |line|
    unless line=~/(.*),(.*)/ then fatal_error("illegal line in #{due}: #{line}") end
    hw,date = [$1.to_i,$2]
    if hw>n_hw_in_syll then n_hw_in_syll=hw end
    if date_to_meeting[date].nil? then fatal_error("date #{date} in #{due} is not in #{reading}") end
    m = date_to_meeting[date]
    meeting_to_hw[m] = hw
    hw_to_meeting[hw] = m
  }
  header = true
  File.readlines(sets).each { |line|
    if header then
      header = false
    else
      # set,book,ch,num,parts,flags,chunk,student
      unless line=~/(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)/ then fatal_error("illegal line in #{sets}: #{line}") end
      hw,ch = [$1.to_i,$3.to_i]
      if hw>n_hw_defined then n_hw_defined=hw end
      m = hw_to_meeting[hw]
      if !m.nil? && (ch_to_meeting[ch].nil? || m<ch_to_meeting[ch]) then
        ch_to_meeting[ch] = m
      end
    end
  }
  0.upto(ch_to_meeting.length-1) { |ch|
    unless ch_to_meeting[ch].nil? then meeting_to_ch[ch_to_meeting[ch]] = ch end
  }
  r = "                          hw     stream's label\n"+
      "hw date       reading     ch     in hw.yaml\n"+
      "-- ---------- ----------- --     --------------\n"
  1.upto(n_meetings) { |m|
    hw = meeting_to_hw[m]
    if hw.nil? || stream_labels[hw].nil? then
      describe_stream_labels=''
    else
      describe_stream_labels=stream_labels[meeting_to_hw[m]]
    end
    if hw.nil? then 
      hw = '--'
      hw_ch='--'
    else
      hw_ch = meeting_to_ch[m]
    end
    r = r +
        pad_string(hw,2,'l')+' '+
        pad_string(meeting_to_date[m],10,'r')+' '+
        pad_string(meeting_to_reading[m],11,'l')+' '+
        pad_string(hw_ch,2,'l')+'     '+
        describe_stream_labels+
        "\n"
  }
  if n_hw_defined!=n_hw_in_syll then
    n_hw_check = "The schedule page of the syllabus has #{n_hw_in_syll} hw assignments, but #{n_hw_defined} are defined.\n"
    $stderr.print n_hw_check
  else
    n_hw_check = "The number of hw assignments on the schedule page of the syllabus matches the number defined; both are #{n_hw_in_syll}\n"
  end
  r = r+n_hw_check
  File.open(args['out_file'],'w') { |f|
    f.print r
  }
end

def pad_string(x,l,side)
  if x.nil? then
    y = ''
  else
    y = x.to_s
  end
  y = y.clone
  while y.length<l do
    if side=='r' then y = y+' ' else y = ' '+y end
  end
  return y
end

################################################################################################


if ARGV.length!=2 then
  fatal_error("illegal arguments: #{ARGV.join(' ')}\nThere should be 2 arguments.\nusage:\n  whiz.rb verb 'json_args'")
end
$verb = ARGV[0]
$args = parse_json_or_die(ARGV[1])

if !($args["header"].nil?) && $args["header"].class.to_s!="Fixnum" then
  fatal_error("argument \"header\" must be integer, not #{$args["header"].class}")
end

def clean_up_and_exit
  $files_to_delete.each { |file|
    FileUtils.rm(file)
  }
  exit(0)
end

if $verb=="parse_hw" then parse_hw($args); clean_up_and_exit end
if $verb=="hw_table" then hw_table($args); clean_up_and_exit end
if $verb=="points_possible" then points_possible_to_csv($args); clean_up_and_exit end
if $verb=="sets_csv" then sets_csv($args); clean_up_and_exit end
if $verb=="roster_csv" then roster_csv($args); clean_up_and_exit end
if $verb=="self_service_hw_list" then self_service_hw_list($args); clean_up_and_exit end
if $verb=="syllabus" then syllabus($args); clean_up_and_exit end
if $verb=="report" then report($args); clean_up_and_exit end
fatal_error("unrecognized verb: #{$verb}")
