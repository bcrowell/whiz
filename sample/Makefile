# Modify the following two directories so that they refer to the
# directories into which you download whiz and lm-solutions from github:
WHIZ =  ~/foo/whiz/whiz.rb
SOLNS_DIR = ~/foo/lm-solutions

#-------------------------------------------------------

CLASS = 221
SEMESTER = s16
SETS_DIR = .
DEFAULT_BOOK = me
   # me=Mechanics, lm=Light and matter, sn=Simple nature, cp=Conceptual physics
SELF_SERVICE_HW = .
BOILERPLATE = .

WHIZ_COMMON_ARGS = "book":"$(DEFAULT_BOOK)","term":"$(SEMESTER)","boilerplate":"boilerplate_for_hw.html"

default:
	@$(WHIZ) parse_hw '{"in_file":"hw.yaml","out_file":"hw.json",$(WHIZ_COMMON_ARGS)}'
	@$(WHIZ) hw_table '{"in_file":"hw.json","out_file":"hw_table.tex",$(WHIZ_COMMON_ARGS)}'
	pdflatex hw_table
	@$(WHIZ) points_possible '{"in_file":"hw.json","out_file":"points_possible.csv",$(WHIZ_COMMON_ARGS)}'
	@$(WHIZ) sets_csv '{"in_file":"hw.json","out_file":"sets.csv","gb_file":"",$(WHIZ_COMMON_ARGS)}'

solutions:
	$(WHIZ) fancy_solutions '{"gb_file":"","in_file":"hw.json","out_file":"temp.m4","class_title":"Physics $(CLASS)","book":"me","sets":"sets.csv","sources_parent_dir":"$(SOLNS_DIR)",$(WHIZ_COMMON_ARGS)}'
	m4 -P solns.m4 temp.m4 >solns$(CLASS).tex
	pdflatex solns$(CLASS)
	pdflatex solns$(CLASS)

clean:
	@rm -f *.aux *.log *~ sets*.csv hw_table.tex converting

very_clean:
	make clean
	rm -f *.csv hw.json hw_table.* report
