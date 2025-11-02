package funkin.backend.scripting;

import haxe.io.Path;
import hscript.Expr.Error;
import hscript.Parser;
import openfl.Assets;
import lscript.*;

import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.LuaOpen;

class LScripts extends Script {
	public var _lua:LScript;
	public var code:String = null;
	public var expr:String;
	//public var folderlessPath:String;
	var __importedPaths:Array<String>;

	// public static function initParser() {
	// 	var parser = new Parser();
	// 	parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
	// 	parser.preprocesorValues = Script.getDefaultPreprocessors();
	// 	return parser;
	// } //不存在好吧hhh

	public override function onCreate(path:String) {
		super.onCreate(path);

		try {
			if(Assets.exists(rawPath)) code = Assets.getText(rawPath);
		} catch(e) Logs.trace('Error while reading $path: ${Std.string(e)}', ERROR);
		//folderlessPath = Path.directory(path);
		_lua = new LScript(true);

		__importedPaths = [path];

		_lua.parseError = (err:String) -> {
            if(path != null)
                Logs.trace('Failed to parse script at ${path}: ${err}');
            else
                Logs.trace('Failed to parse script: ${err}');
        };
		_lua.functionError = (func:String, err:String) -> {
            if(path != null)
                Logs.trace('Failed to call function "$func" at ${path}: ${err}');
            else
                Logs.trace('Failed to call function "$func": ${err}');
        };
		_lua.tracePrefix = (path != null) ? fileName : 'Lua';
		//_lua.parseError = importFailedCallback;

		_lua.print = (line:Int, s:String) -> {
            Logs.trace('${_lua.tracePrefix}:${line}: ${s}');
        };



		this.setParent(this);

		this.expr = code;

		#if GLOBAL_SCRIPT
		funkin.backend.scripting.GlobalScript.call("onScriptCreated", [this, "lua"]);
		#end
	}

	public override function loadFromString(code:String) {
		try{
		_lua.execute(code);
	    }

		return this;
	}

	private function importFailedCallback(cl:Array<String>):Bool {
		var assetsPath = 'assets/source/${cl.join("/")}';
		var luaExt = "lua";
		var p = '$assetsPath.$luaExt';
		
		if (__importedPaths.contains(p))
			return true; // no need to reimport again
			
		if (Assets.exists(p)) {
			var code = Assets.getText(p);
			if (code != null && code.trim() != "") {
				try {
					_lua.execute(code);
					__importedPaths.push(p);
				} catch(e) {
					_errorHandler('Error loading Lua file $p: ${Lua.tostring(_lua.luaState, -1)}');
				}
			}
			return true;
		}
		return false;
	}

	private function _errorHandler(error:String) {
    try {
        var fileName = error;
        if(remappedNames.exists(fileName))
            fileName = remappedNames.get(fileName);
            
        var fn = '$fileName:${Lua.tostring(_lua.luaState, -1)}: ';
        var err = Lua.tostring(_lua.luaState, -1);
        
        if (err == null) {
            Logs.traceColored([
                Logs.logText('Script Error: ', RED),
                Logs.logText('Failed to get error message from Lua state', RED)
            ], ERROR);
            return;
        }
        
        if (err.startsWith(fn)) err = err.substr(fn.length);

        Logs.traceColored([
            Logs.logText(fn, GREEN),
            Logs.logText(err, RED)
        ], ERROR);
			#if mobile
            NativeAPI.showMessageBox("Codename Engine Crash Handler (Lua)", fn + err, MSG_ERROR);
	    #end
    } catch(e:Dynamic) {
        Logs.traceColored([
            Logs.logText('Critical Error: ', RED),
            Logs.logText('Error handler failed: ${Std.string(e)}', RED)
        ], ERROR);
    }

	}

	public override function setParent(parent:Dynamic) {
		_lua.parent = parent;
	}

	public override function onLoad() {
		if (expr != null) {
			_lua.execute(expr);
			call("new", []);
		}

		#if GLOBAL_SCRIPT
		funkin.backend.scripting.GlobalScript.call("onScriptSetup", [this, "lua"]);
		#end
	}

	public override function reload() {
		onCreate(path);

		for(k=>e in Script.getDefaultVariables(this))
			set(k, e);

		load();
		loadFromString(expr);
		setParent(this);

		// for(k=>e in savedVariables)
		// 	set(k, e);
	}

	private override function onCall(funcName:String, parameters:Array<Dynamic>):Dynamic {
    try {
        var ret:Dynamic = _lua.callFunc(funcName, parameters != null ? parameters : []);
        return ret;
    } catch(e:Dynamic) {
        _errorHandler('Error calling function ${funcName}: ${Std.string(e)}');
        return null;
    }
}

	public override function get(val:String):Dynamic {
        return _lua.getVar(val);
	}

	public override function set(val:String, value:Dynamic) {
        return _lua.setVar(val, value);
	}

	public override function trace(v:Dynamic) {
		var info:Lua_Debug = {};
		Lua.getstack(_lua.luaState, 1, info);
		Lua.getinfo(_lua.luaState, "l", info);

		Logs.traceColored([
			Logs.logText('${fileName}:${info.currentline}: ', GREEN),
			Logs.logText(Std.isOfType(v, String) ? v : Std.string(v))
		], TRACE);
	}

	// public override function setPublicMap(map:Map<String, Dynamic>) {
	// 	this._lua.GlobalVars = map;
	// }
}
