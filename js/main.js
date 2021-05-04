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
		this._errors.push(msg);
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
error_logger = new error_logger();

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
