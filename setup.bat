
haxelib --global git haxelib https://github.com/FunkinCrew/haxelib.git
haxelib --global remove hmm
haxelib --global git hmm  https://github.com/FunkinCrew/hmm.git
haxelib --global run hmm setup
hmm reinstall -f
lime rebuild tools -clean
lime rebuild windows -clean