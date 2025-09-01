.PHONY: all clean

all:
	@echo "Starting SAC compilation benchmark..."
	@./benchmark.sh

clean:
	@echo "Cleaning up generated files..."
	@rm -f *.mod *.c *.o *.h
	@rm -f results.csv
	@rm -f 0-param 1-param 2-param 3-param 4-param 5-param 6-param 7-param 8-param 9-param
	@rm -f 10-param 11-param 12-param 13-param 14-param 15-param 16-param 17-param 18-param 19-param
	@echo "Cleanup complete."