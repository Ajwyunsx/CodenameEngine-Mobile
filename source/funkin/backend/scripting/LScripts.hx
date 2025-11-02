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
	var __importedPaths:Array<String>;

	public override function onCreate(path:String) {
		super.onCreate(path);

		try {
			if(Assets.exists(rawPath)) code = Assets.getText(rawPath);
		} catch(e) {
			handleScriptError("File Read", e);
		}

		_lua = new LScript(true);
		__importedPaths = [path];

		_lua.parseError = (err:String) -> handleScriptError("Parse", err);
		_lua.functionError = (func:String, err:String) -> handleScriptError("Function Call", err, func);
		_lua.tracePrefix = (path != null) ? fileName : 'Lua';

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
		try {
			_lua.execute(code);
		} catch(e) {
			handleScriptError("Execute String", e);
		}
		return this;
	}

	private function importFailedCallback(cl:Array<String>):Bool {
		var assetsPath = 'assets/source/${cl.join("/")}';
		var luaExt = "lua";
		var p = '$assetsPath.$luaExt';
		
		if (__importedPaths.contains(p))
			return true;
			
		if (Assets.exists(p)) {
			var code = Assets.getText(p);
			if (code != null && code.trim() != "") {
				try {
					_lua.execute(code);
					__importedPaths.push(p);
				} catch(e) {
					handleScriptError("Import", e, 'import ${cl.join("/")}');
				}
			}
			return true;
		}
		return false;
	}

	
	private function handleScriptError(context:String, error:Dynamic, ?funcName:String) {
		
		var location = path != null ? ' in script "${path}"' : ' in an unknown script';
		var funcInfo = funcName != null ? ' (in function "${funcName}")' : '';
		var errorMsg = 'Error during ${context}${location}${funcInfo}:\n${Std.string(error)}';

		Logs.traceColored([
			Logs.logText('[LUA ERROR] ', RED),
			Logs.logText('During ${context}', YELLOW),
			Logs.logText(location, GRAY),
			funcInfo != null ? Logs.logText(funcInfo, GRAY) : null,
			Logs.logText(': \n${Std.string(error)}', RED)
		], ERROR);

		#if mobile
		NativeAPI.showMessageBox("Codename Engine - Lua Script Error", errorMsg, MSG_ERROR);
		#end
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
	}

	private override function onCall(funcName:String, parameters:Array<Dynamic>):Dynamic {
		try {
			var ret:Dynamic = _lua.callFunc(funcName, parameters != null ? parameters : []);
			return ret;
		} catch(e:Dynamic) {
			handleScriptError("Function Call", e, funcName);
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
}
