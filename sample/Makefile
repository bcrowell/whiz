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

WHIZ_COMMON_ARGS = "book":"$(DEFAULT_BOOK)","term":"$(SEMESTER)","boilerplate":"boilerplate_for_hw.html""

default:
	@$(WHIZ) parse_hw '{"in_file":"hw.yaml","out_file":"hw.json",$(WHIZ_COMMON_ARGS)}'
	@$(WHIZ) hw_table '{"in_file":"hw.json","out_file":"hw_table.tex",$(WHIZ_COMMON_ARGS)}'

blah:
	@perl -e 'if (system("pdflatex hw_table >err")) {$(SHOW_ERRORS)}'
	@$(WHIZ) points_possible '{"in_file":"hw.json","out_file":"points_possible.csv",$(WHIZ_COMMON_ARGS)}'
	@mkdir -p $(SETS_DIR)
	@cp points_possible.csv $(SETS_DIR)
	@$(WHIZ) sets_csv '{"in_file":"hw.json","out_file":"sets$(CLASS)$(SUFFIX).csv","gb_file":"$(GB)",$(WHIZ_COMMON_ARGS)}'
	@cp sets$(CLASS)$(SUFFIX).csv $(SETS_DIR)
	@$(WHIZ) self_service_hw_list '{"in_file":"hw.json","out_file":"$(SELF_SERVICE_HW)/221.html","class_title":"Physics 221","boilerplate_instructions":"boilerplate_instr.html",$(WHIZ_COMMON_ARGS)}'
	@$(WHIZ) groups '{"gb_file":"$(GB)","out_file":"$(GROUPS)/221$(SUFFIX).html","class_title":"Physics 221",$(WHIZ_COMMON_ARGS)}'
	@cp due221$(SEMESTER).csv $(SETS_DIR)
	@$(WHIZ) roster_csv '{"out_file":"roster.csv","gb_file":"$(GB)",$(WHIZ_COMMON_ARGS)}'
	@$(WHIZ) report '{"in_file":"hw.json","out_file":"report","due":"due221$(SEMESTER).csv","reading":"reading.csv","sets":"sets$(CLASS)$(SUFFIX).csv","out_file2":"problems_assigned","allow_gaps":"1",$(WHIZ_COMMON_ARGS)}'
	@echo "A report of coordination between hw and reading is in the file report. Another report is in problems_assigned."

clean:
	@rm -f *.aux *.log syll*.pdf *~ sets*.csv syll221*${SEMESTER}.tex err converting syll.rbtex

very_clean:
	make clean
	rm -f *.csv hw.json hw_table.* report

solns:
	$(WHIZ) fancy_solutions '{"gb_file":"$(GB)","in_file":"hw.json","out_file":"temp.m4","class_title":"Physics 205/210","book":"lm","sets":"$(SETS_DIR)/sets205.csv","sources_parent_dir":"/home/bcrowell/Documents/teaching/solns",$(WHIZ_COMMON_ARGS)}'
	m4 -P solns.m4 temp.m4 >solns205.tex
	pdflatex solns205
	pdflatex solns205
	@mv solns205.pdf $(SOLNS_DIR)/solns205.pdf
	@perl -e 'if ("$(SUFFIX)" ne "") {system("mv $(SOLNS_DIR)/solns205.pdf $(SOLNS_DIR)/solns205$(SUFFIX).pdf")}'
	@echo "The file $(SOLNS_DIR)/solns205$(SUFFIX).pdf contains both 205 and 210 solutions."
