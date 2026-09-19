TARGETS := \
  cache-inconsistency.svg \
  compiler-pipeline.svg \
  gem5-cpu-memory-system.svg \
  gem5-queues.svg \
  generic-compiler-pipeline-1.svg \
  generic-compiler-pipeline-2.svg \
  memory-hierarchy.svg \
  cache-hierarchy.svg \


all: $(TARGETS)

%.svg: %.pdf
	pdf2svg $< $@

%.pdf: %.tex
	pdflatex $< -o $@

clean:
	rm -f $$(cat .gitignore)

.PHONY: all clean
.PRECIOUS: %.pdf
