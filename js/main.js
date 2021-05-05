/* jshint node:true, esversion:8*/
"use strict";

// there may well be a good library for this
// as of the time of writing this I have not written much javascript code
// for now being able to peel away the layers and control the svg being created is valuable
// this may well change at a later date
// this is intended to not have any real logic within it, and be possible to switch out if I learn/am tought a better library / way
const svg_helper = {
	create_svg : function(width,height,viewport_x,viewport_y,viewport_width,viewport_height) {
		const svgData = document.createElementNS("http://www.w3.org/2000/svg","svg");
		svgData.setAttribute("id","svgData");
		svgData.setAttribute("version","1.1");
		svgData.setAttribute("width",width);
		svgData.setAttribute("height",height);
		svgData.setAttribute("viewBox",""+viewport_x+","+viewport_y+",+"+viewport_width+",+"+viewport_height);
		return svgData;
	},
	create_circle : function(cx,cy,r) {
		const circle=document.createElementNS("http://www.w3.org/2000/svg","circle");
		circle.setAttribute("cx",cx);
		circle.setAttribute("cy",cy);
		circle.setAttribute("r",r);
		return circle;
	},
	create_path : function(d) {
		const path=document.createElementNS("http://www.w3.org/2000/svg","path");
		path.setAttribute("d",d);
		return path;
	},
	create_line : function(x1,y1,x2,y2) {
		const line=document.createElementNS("http://www.w3.org/2000/svg","line");
		line.setAttribute("x1",x1);
		line.setAttribute("y1",y1);
		line.setAttribute("x2",x2);
		line.setAttribute("y2",y2);
		return line;
	},
	create_g : function(fill,color) {
		const g=document.createElementNS("http://www.w3.org/2000/svg","g");
		g.setAttribute("fill",fill);
		g.setAttribute("stroke",color);
		return g;
	},
	create_png_image : function(x,y,width,height,data_url) {
		const img=document.createElementNS("http://www.w3.org/2000/svg","image");
		img.setAttribute("x",x);
		img.setAttribute("y",y);
		img.setAttribute("width",width);
		img.setAttribute("height",height);
		img.setAttribute("href",data_url);
		return img;
	}
};
Object.freeze(svg_helper);

// generic libraries
// designed for things that there may well be javascript libraries out there
// if there are it certainly wouldnt be a bad idea to convert to them
const util = {
	// converts a url on a website to a data URI
	convertImageToURI : function(url) {
		return new Promise (resolve => {
			const image = new Image();
			image.onload = function () {
				const canvas = document.createElement('canvas');
				canvas.width = this.naturalWidth;
				canvas.height = this.naturalHeight;
				canvas.getContext('2d').drawImage(this, 0, 0);
				resolve(canvas.toDataURL('image/png'));
			};
			image.src = url;
			return image;
		});
	},
	removeAllChildren : function(node) {
		while (node.firstChild) {
			node.removeChild(node.firstChild);
		}
	},
};
Object.freeze(util);

class error_logger {
	constructor() {
		this._errors=[];
	}
	error(msg) {
		console.log(msg);
		this._errors.push(msg);
		if (gm_ui) {
			gm_ui.update_button_list();
		}
	}
	get_errors() {
		return this._errors;
	}
	get_button_text() {
		let error_text="errors";
		if (this._errors.length!=0) {
			error_text+=" "+"("+this._errors.length+")";
		}
		return error_text;
	}
}

// functions that are directly related to the EE server
// so functions that edit exec.lua , get.lua and set.lua
// along with functions to manipulate the data from the server
const ee_server = {
	// convert the JSON returned from EE to an array
	convert_lua_json_to_array : function(json) {
		const ret=[];
		// might not need sorting, but I dont think speed matters and I havent confirmed
		Object.entries(json).sort().forEach(item => {
			ret.push(item[1]);
		});
		return ret;
	},
	// run exec_lua with the code provided
	exec : async function(lua_code) {
		if (typeof(lua_code)!="string") {
			throw new Error("exec not passed a "+typeof(lua_code)+" rather than the expected string, probably an internal error in this web page.");
		}
		const max_exec_length=2048; // this is a constant inside of EE
		// There also is an execution time limit, but that is something I havent tested yet
		if (lua_code.length > max_exec_length) {
			throw "attemped to upload a exec file too large for ee - size = " + lua_code.length;
		}
		const response = await fetch(window.location.protocol+"//"+window.location.host+"/exec.lua",{
			method:"POST",
			body:lua_code
		});
		if (response.ok) {
			const raw_response_text = await response.text();
			// in the case of error EE will put newlines into the script which is wrong, hacky fix
			// at some point EE should be fixed and much fo this can be replaced with a response.json()
			const fixed_response_text=raw_response_text.replace(/[\r]/gm,'');
			try {
				const ret=JSON.parse(fixed_response_text);
				if (ret.ERROR) {
					throw ret.ERROR;
				} else {
					return ret;
				}
			} catch (err) {
				throw "---\njson not returned from EE - response =\"" + fixed_response_text + "\"\n----";
			}
		} else {
			throw "exec error " + await response.text();
		}
	},
	fetch_file : async function(filename) {
		const response = await fetch(filename);
		if (!response.ok) {
			if (response.status==404) {
				throw new Error("fetch error - file not found \"" + response.url+"\"");
			} else {
				throw new Error("fetch error " + response.text());
			}
		}
		return response.text();
	}
};
Object.freeze(ee_server);

class data_cache {
	constructor () {
		this._cache = {};
	}
	has_key(key) {
		return this._cache.hasOwnProperty(key);
	}
	// it is expected but not required that the value is a promise
	set(key,value) {
		if (this.has_key(key)) {
			throw new Error("attempted to add duplicate entry into the a cache");
		}
		this._cache[key]=value;
	}
	async get(key) {
		if (this.has_key(key)) {
			return this._cache[key];
		} else {
			throw "cached element \"" + key+"\" requested which doesnt exist";
		}
	}
	// used for saving it into web storage / JSON files
	async get_whole_cache () {
		for (const key in this._cache) {
			if (this.has_key(key)) {
				this._cache[key]=await this._cache[key];
			}
		}
		return this._cache;
	}
	// TODO add set cache option
}

// get all of the model data
// mainly used for infomation like beam port starts, scale of the model etc
// the things we want out of it may be possible to expose via new EE scripting
// in which case this may stop needing to exist
class get_model_data {
	constructor (cache) {
		this._cache=cache;
		this._cache.set("model_data",this.resolve());
	}
	async resolve() {
		const lua=gm_tool.get_lua_without_cache("get_model_data");
		const models=ee_server.convert_lua_json_to_array(await ee_server.exec(await lua));
		const ret = {};
		models.forEach(model => {
			if ('BeamPosition' in model) {
				model.BeamPosition=ee_server.convert_lua_json_to_array(model.BeamPosition);
			}
			const name = model.Name;
			delete model.Name;
			ret[name]=model;
		});
		return ret;
	}
	async get() {
		return this._cache.get("model_data");
	}
}

// get template data that cant be fetched from a live object of that type
// it may be possible with time and work for this to be removed
// this would require EE scripting to be exapanded
class get_extra_template_data{
	constructor (cache) {
		this._cache=cache;
		this._cache.set("template_data",this.resolve());
	}
	async resolve() {
		const lua=gm_tool.get_lua_without_cache("get_extra_template_data");
		const raw=await ee_server.exec(await lua);
		const template_data=ee_server.convert_lua_json_to_array(raw);
		const ret = {};
		template_data.forEach(template => {
			if ('Name' in template) {
				const name = template.Name;
				delete template.Name;
				ret[name]=template;
			} else {
				throw new Error("possible invalid template file");
			}
		});
		return ret;
	}
	async get() {
		return this._cache.get("template_data");
	}
}

class gm_tool {
	// this needs to be called before any other members are used
	async init() {
		this._ee_cache = new data_cache();
		// set up all of the classes for server requesting data
		this.get_model_data = new get_model_data(this._ee_cache);
		this.get_extra_template_data = new get_extra_template_data(this._ee_cache);
	}
	async get_whole_cache() {
		return this._ee_cache.get_whole_cache();
	}
	async get_lua_without_cache(filename) {
		return ee_server.fetch_file("lua/"+filename+".lua");
	}
}

class error_log_tab {
	get_button_text () {
		return error_logger.get_button_text();
	}
	async show () {
		const page=document.createElement("div");
		// TODO it would be nice if this updated if the error_logger had new errors
		error_logger.get_errors().forEach(error => {
			page.appendChild(document.createTextNode(error));
			page.appendChild(document.createElement("br"));
			// if we have a stacktrace we add it
			if (typeof(error)!='string' && 'stack' in error) { // should be == object
				page.appendChild(document.createTextNode(error.stack));
				page.appendChild(document.createElement("br"));
			}
		});
		return page;
	}
}

class debug_tab {
	async show() {
		const page=document.createElement("div");
		const cache_details=document.createElement("table");
		page.appendChild(cache_details);
		const cache=await gm_tool.get_whole_cache();

		// show all of the sizes for the cache
		// TODO it might be nice to convert these to kb/mb
		const row=cache_details.insertRow();
		row.insertCell().appendChild(document.createTextNode("total size"));
		row.insertCell().appendChild(document.createTextNode(JSON.stringify(cache).length));
		for (const key in cache) {
			if (cache.hasOwnProperty(key)) {
				const row=cache_details.insertRow();
				row.insertCell().appendChild(document.createTextNode(key));
				row.insertCell().appendChild(document.createTextNode(JSON.stringify(cache[key]).length));
			}
		}
		return page;
	}
	get_button_text() {
		return "debug";
	}
}

class ui {
	constructor () {
		this._tabs = [
			new debug_tab(),
			new error_log_tab(),
		];
		this.update_button_list();
		this._last_url="";
	}
	update_button_list() {
		const tabs=document.getElementById("tab-buttons");
		util.removeAllChildren(tabs);
		this._tabs.forEach(tab => {
		const button = document.createElement("button");
			button.textContent=tab.get_button_text();
			button.tab_class=tab;
			button.onclick= function(){
				gm_ui.switch_to(this.tab_class);
			};
			tabs.appendChild(button);
		});
	}
	async switch_to(tab) {
		try {
			util.removeAllChildren(document.getElementById("main-tab"));
			this._active_tab=tab;
			document.getElementById("main-tab").appendChild(await tab.show());
			this.update_history();
		} catch (error) {
			error_logger.error(error);
		}
	}
	update_history() {
		let url='index.html?'
		if (this._active_tab && this._active_tab.page_name != undefined) {
			url=url+"page="+this._active_tab.page_name;
		}
		if (this._last_url!=url) {
			this.last_url=url;
			history.pushState(null, '', url);
		}
	}
	async load_page(page) {
		const args=page.substring(1).split('=');
		if (args.length == 2) {
			if (args[0] == "page") {
				this._tabs.forEach (potentialTab => {
					if (potentialTab.page_name == args[1]) {
						gm_ui.switch_to(potentialTab);
					}
				});
			}
		}
	}
}

error_logger = new error_logger();
window.addEventListener("unhandledrejection", function(e) {
	error_logger.error(e.reason);
	e.preventDefault();
});

gm_tool=new gm_tool();
gm_tool.init();

let gm_ui='';
window.onload=function () {
	gm_ui = new ui();
	gm_ui.load_page(window.location.search);
};
