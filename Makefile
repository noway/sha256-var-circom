.PHONY: test

test: snark-jwt-verify
	yarn exec mocha

snark-jwt-verify/: 
	git clone --recurse-submodules https://github.com/TheFrozenFire/snark-jwt-verify

clean:
	rm -rf snark-jwt-verify