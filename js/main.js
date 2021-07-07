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
		const circle = document.createElementNS("http://www.w3.org/2000/svg","circle");
		circle.setAttribute("cx",cx);
		circle.setAttribute("cy",cy);
		circle.setAttribute("r",r);
		return circle;
	},
	create_path : function(d) {
		const path = document.createElementNS("http://www.w3.org/2000/svg","path");
		path.setAttribute("d",d);
		return path;
	},
	create_line : function(x1,y1,x2,y2) {
		const line = document.createElementNS("http://www.w3.org/2000/svg","line");
		line.setAttribute("x1",x1);
		line.setAttribute("y1",y1);
		line.setAttribute("x2",x2);
		line.setAttribute("y2",y2);
		return line;
	},
	create_g : function(fill,color) {
		const g = document.createElementNS("http://www.w3.org/2000/svg","g");
		g.setAttribute("fill",fill);
		g.setAttribute("stroke",color);
		return g;
	},
	create_png_image : function(x,y,width,height,data_url) {
		const img = document.createElementNS("http://www.w3.org/2000/svg","image");
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

class error_logger_class {
	constructor() {
		this._errors = [];
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
			error_text += " "+"("+this._errors.length+")";
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
		Object.entries(json).forEach(item => {
			ret.push(item[1]);
		});
		return ret;
	},
	max_exec_length : 16384, // this is a constant inside of EE
	// run exec_lua with the code provided
	// TODO errors should give a script name
	exec : async function(lua_code,error_location) {
		if (typeof(lua_code) != "string") {
			throw new Error("exec not passed a "+typeof(lua_code)+" rather than the expected string, probably an internal error in this web page.");
		}
		// There also is an execution time limit, but that is something I havent tested yet
		if (lua_code.length > this.max_exec_length) {
			throw new Error("attemped to upload a exec file too large for ee - size = " + lua_code.length);
		}
		const response = await fetch(window.location.protocol+"//"+window.location.host+"/exec.lua",{
			method:"POST",
			body:lua_code
		});
		if (response.ok) {
			const raw_response_text = await response.text();
			// at some point EE should be fixed and much fo this can be replaced with a response.json()
			// \ is currently not escaped in EE
			let fixed_response_text = raw_response_text.replace(/\\/g,'\\\\');
			// in the case of error EE will put newlines into the script which is wrong, hacky fix
			fixed_response_text = fixed_response_text.replace(/[\r]/gm,'').replace(/[\n]/gm,'\\n');
			// qoutes are not generally correctly escaped
			// this needs fixing inside of EE, but we can fix the one situation of a single string being returned for right now
			if (fixed_response_text[0] && fixed_response_text[fixed_response_text.length-1]=='"') {
				fixed_response_text = fixed_response_text.replace(/"(.)/g,'\\"$1');
				fixed_response_text = fixed_response_text.replace(/\t/g,'\\t')
				fixed_response_text = fixed_response_text.substring(1);
			}
			if (fixed_response_text != "") {
				let ret;
				try {
					ret=JSON.parse(fixed_response_text);
				} catch (err) {
					throw new Error("---\njson not returned from EE - response =\"" + fixed_response_text + "\"\n----");
				}
				if (ret && ret.ERROR) {
					if (error_location) {
						ret.ERROR = "within file"+error_location+"\n" + ret.ERROR;
					}
					throw ret.ERROR;
				} else {
					return ret;
				}
			}
		} else {
			throw new Error("exec error " + await response.text());
		}
	},
	fetch_file : async function(filename) {
		const response = await fetch(filename);
		if (!response.ok) {
			if (response.status == 404) {
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
		this._cache[key] = value;
	}
	async get(key) {
		if (this.has_key(key)) {
			return this._cache[key];
		} else {
			throw new Error("cached element \"" + key+"\" requested which doesnt exist");
		}
	}
	// used for saving it into web storage / JSON files
	async get_whole_cache () {
		for (const key in this._cache) {
			if (this.has_key(key)) {
				this._cache[key] = await this._cache[key];
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
		this._cache = cache;
		// this needlessly fills the cache with the lua
		// this could be fixed, but is not currently important
		this._lua_wrapper = new lua_wrapper("get_model_data",caution_level.safe);
		this._cache.set("model_data",this.resolve());
	}
	async resolve() {
		const models = ee_server.convert_lua_json_to_array(await this._lua_wrapper.run());
		const ret = {};
		models.forEach(model => {
			model.BeamPosition=ee_server.convert_lua_json_to_array(model.BeamPosition);
			const name = model.Name;
			delete model.Name;
			ret[name] = model;
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
		this._cache = cache;
		// this needlessly fills the cache with the lua
		// this could be fixed, but is not currently important
		this._lua_wrapper = new lua_wrapper("get_extra_template_data",caution_level.safe);
		this._cache.set("template_data",this.resolve());
	}
	async resolve() {
		const raw = await this._lua_wrapper.run();
		const template_data = ee_server.convert_lua_json_to_array(raw);
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

class lua_wrapper {
	constructor(filename,caution) {
		this._filename = filename;
		this._lua = gm_tool.cache_get_lua(filename);
		this._caution = caution;
	}
	async run (settings) {
		if (settings === undefined) {
			settings = {};
		}
		let code = "";
		for (const v in settings) {
			if (settings.hasOwnProperty(v)) {
				code += v + "=";
				if (typeof(settings[v]) === "string") {
					code += '"' + settings[v].replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/\r/g,'').replace(/\n/g,'\\n') + '"';
				} else {
					code += settings[v];
				}
				code += "\n";
			}
		}
		code += await this._lua;
		return gm_tool.exec_lua(code,this._caution,this._filename);
	}
}

class get_cpuship_soft_templates {
	constructor(cache) {
		this._cache = cache;
		// this basically cant become non reckless
		// this is due to the fact its running random chunks of sandbox code
		// its probably possible to make it behave better, but flawless is unlikely
		this._lua = new lua_wrapper("sandbox/get_cpuship_soft_tempate",caution_level.reckless);
		this._cache.set("npc_ships",this.resolve());
	}
	async resolve() {
		const ret = ee_server.convert_lua_json_to_array(await this._lua.run());
		console.log(ret);
		return ret;
	}
	async get() {
		return this._cache.get("npc_ships");
	}
}

// at the moment this is rather jumbled between getting the soft template and the actual template
// at some point this will probably be cleared up, but at the moment it is something to keep in mind
class get_player_soft_template {
	constructor(cache) {
		this._cache = cache;
		// this is labeled reckless due to the creation and destruction of a playerShip
		// with more lua side error checking, along with thought about onNewPlayerShip this may be possible to change
		this._lua = new lua_wrapper("get_player_soft_template",caution_level.reckless);
	}
	async _postprocess(raw) {
		raw = await raw;
		// get data needed for the all the postprocessing
		// TODO needs to handle ships with their typename changed
		// this will break almost all of xanstas soft template ships
		const template = (await gm_tool.get_extra_template_data.get())[raw.TypeName];
		const model = (await gm_tool.get_model_data.get())[template.Model];

		Object.entries(raw.Beams).forEach(([beam_num,beam]) => {
			if (model.BeamPosition[beam_num-1]) {
				beam.start_x = model.BeamPosition[beam_num-1].x;
				beam.start_y = model.BeamPosition[beam_num-1].y;
				beam.start_z = model.BeamPosition[beam_num-1].z;
			} else {
				beam.start_x = 0;
				beam.start_y = 0;
				beam.start_z = 0;
			}
			// remove beams that have been disabled in lua
			// beam range is limited to max(0.1,requested_length)
			// as such there are a number of sub 1u beams that arent really present
			if (beam.Range<1) {
				delete raw.Beams[beam_num];
			}
		});

		raw.Beams = ee_server.convert_lua_json_to_array(raw.Beams);
		raw.RadarTrace = template.RadarTrace; // sadly we lack a playership::getRadarTrace() currently
		raw.Scale = model.Scale;
		raw.ShieldMax = ee_server.convert_lua_json_to_array(raw.ShieldMax);

		return raw;
	}
	async get (template_name) {
		const cache_entry = "template-" + template_name;
		if (!this._cache.has_key(cache_entry)) {
			this._cache.set(cache_entry,this._postprocess(this._lua.run({ship_template : template_name})));
		}
		return this._cache.get(cache_entry);
	}
}

const caution_level = {
	reckless : 1,
	safe : 2,
	cautious : 3,
	no_execs : 4,
};
Object.freeze(caution_level);

class gm_tool_class {
	constructor() {
		this.caution_level = caution_level.safe;
	}
	// this needs to be called before any other members are used
	async init() {
		this._ee_cache = new data_cache();
		// set up all of the classes for server requesting data
		this.get_model_data = new get_model_data(this._ee_cache);
		this.get_extra_template_data = new get_extra_template_data(this._ee_cache);
		this.get_player_soft_template = new get_player_soft_template(this._ee_cache);
		this.get_cpuship_data = new get_cpuship_soft_templates(this._ee_cache);
		// this probably wants splitting into boostrap code (less than 1 EE upload segment) including upload_to_script_storage
		// and everything else (with it being conditionally executed if not already loaded)
		this._bootstrap = new lua_wrapper("bootstrap",caution_level.cautious);
		await this._bootstrap.run();
		this._www_gm_tools = new lua_wrapper("www_gm_tools",caution_level.cautious);
		await this._www_gm_tools.run();
	}
	set_caution_level(level) {
		this.caution_level = caution_level[level];
	}
	async call_www_function(name) {
		let code = "return getScriptStorage()._cuf_gm."+name+"(";
		let first = true;
		const args = Array.from(arguments);
		args.splice(0,1);
		args.forEach(arg => {
			if (first) {
				first = false;
			} else {
				code += ",";
			}
			if (typeof(arg) === "string") {
				console.log(arg)
				code += '"' + arg.replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/\r/g,'').replace(/\n/g,'\\n') + '"';
			} else if (typeof(arg)=="object") {
				// this needs some sort of merging with the code for args
				code += "{";
				let inner_first = true;
				for (const key in arg) {
					console.log(key)
					if (inner_first) {
						inner_first = false;
					} else {
						code += ",";
					}
					code += key +" = ";
					if (typeof(arg[key]) === "string") {
						code += '"' + arg[key].replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/\r/g,'').replace(/\n/g,'\\n') + '"';
					} else {
						code += arg[key];
					}
				}
				code += "}";
			} else {
				code += arg;
			}
		});
		code+=")";
		return this.exec_lua(code,caution_level.safe,""); // safe is wrong
	}
	async upload_to_script_storage_and_exec(str) {
		const max_length = ee_server.max_exec_length/2;// we are just going to be cautious on the chunks we upload rather than check the exact number of chars
		const id = await this.call_www_function("upload_start");
		let i = 0;
		for (;;) {
			const cur_string = str.slice(i*max_length,(i+1)*max_length);
			i++;
			const response = await this.call_www_function("upload_segment",id,cur_string);
			if (i*max_length>str.length) {
				break;
			}
		}
		// TODO we should clear old strings
		await this.call_www_function("upload_end",id);
	}
	async get_whole_cache() {
		return this._ee_cache.get_whole_cache();
	}
	async cache_get_lua(filename) {
		const cache_name = filename+".lua";
		if (!this._ee_cache.has_key(cache_name)) {
			this._ee_cache.set(cache_name,ee_server.fetch_file("lua/"+cache_name));
		}
		return this._ee_cache._cache[cache_name];
	}
	async exec_lua(code,caution,filename) {
		if (caution == undefined) {
			throw new Error("caution level not set");
		}
		if (caution >= this.caution_level) {
			if (code.length <= ee_server.max_exec_length) {
				return ee_server.exec(code,filename);
			} else {
				this.upload_to_script_storage_and_exec(code);
			}
		} else {
			throw new Error("script set to be more cautious than this level of running. End users seeing this message is a bug");
		}
	}
	async cache_image_uri(url) {
		const cache_name = url;
		if (!this._ee_cache.has_key(cache_name)) {
			this._ee_cache.set(cache_name,util.convertImageToURI(url));
		}
		return this._ee_cache._cache[cache_name];
	}
	// this needs thought when templates and soft templates are properly split
	// at that time its worth considering if it should only return the keys to be fed into
	// the template and soft template functions
	async get_all_player_templates() {
		const templates = await this.get_extra_template_data.get();
		const ret = {};
		for (const name in templates) {
			if (templates.hasOwnProperty(name)) {
				if (templates[name].Type == "playership") {
					ret[name] = templates[name];
				}
			}
		}
		return ret;
	}
	// there kind of wants to be a for_each_player_template
	// before adding it consider how it will interact with async code
	// the obvious answer is badly, thus I'm not writing it right now
}

// elements that should be generic between several EE svg generators
const svg_elements = {
	// the lines on the radar
	// the scale is in milli-units (IE the same distance used for beams, not the sci distance)
	create_radar_ovelay : function(num_rings) {
		let radar=svg_helper.create_g("none","#A8A8A8");
		radar.setAttribute("stroke-width",25);
		for (let i=1; i<=num_rings; i++) {
			radar.appendChild(svg_helper.create_circle(0,0,i*1000));
		}
		const radar_lines = 12;
		for (let i=0; i<radar_lines; i++) {
			const angle = Math.PI*2/radar_lines*i;
			const line_length = Math.floor(num_rings)*1000;
			const x2 = line_length*Math.sin(angle);
			const y2 = line_length*Math.cos(angle);
			radar.appendChild(svg_helper.create_line(0,0,x2,y2));
		}
		return radar;
	}
};

class player_template_data_card {
	constructor (template_name) {
		this._data = gm_tool.get_player_soft_template.get(template_name);
	}
	_create_beam_arcs(ship_data) {
		const beams = ship_data.Beams;
		const beams_element=svg_helper.create_g("none","#ff0000");
		beams.forEach(beam => {
// TODO turret arc
			const beam_cx = beam.start_x*ship_data.Scale;// maybe this should be pre multiplied?
			const beam_cy = beam.start_y*ship_data.Scale;
			const beam_length = beam.Range;
			const direction1 = (beam.Direction+90-(beam.Arc/2))/360*(Math.PI*2);
			const direction2 = direction1+(beam.Arc/360*(Math.PI*2));
			const dx1 = beam_length*Math.sin(direction1);
			const dy1 = beam_length*Math.cos(direction1);
			const dx2 = beam_length*Math.sin(direction2);
			const dy2 = beam_length*Math.cos(direction2);
			const path_data = "M "+beam_cx+" "+beam_cy+" l "+dx1+" "+dy1+
			// todo large arc
			" M "+beam_cx+" "+beam_cy+" m "+dx1+" "+dy1+"A"+beam_length+" "+beam_length+" 0 0 0 "+(dx2+beam_cx)+" "+(dy2+beam_cy)+
			" M "+beam_cx+" "+beam_cy+" l "+dx2+" "+dy2;
			beams_element.appendChild(svg_helper.create_path(path_data));
		});
		return beams_element;
	}
	// compute beam arcs
	// take each path
	// calculate where they interesect
	// if it intersects split at that point, calculate next intersection
	async get_svg(){
		const data = await this._data;
		const svgData = svg_helper.create_svg(300,300,0,0,10000,10000);
		const radar = svg_elements.create_radar_ovelay(5);
		radar.setAttribute("transform","translate(5000,5000)");
		radar.appendChild(this._create_beam_arcs(data));

		//TODO the x,y locations are placed probably wrongly
		// TODO width, height are pre scaled (and probably wrong)
		const uri = await gm_tool.cache_image_uri("resources/"+data.RadarTrace);
		radar.appendChild(svg_helper.create_png_image(-250,-250,500,500,uri));
		//console.log(new XMLSerializer().serializeToString(svgData));
		svgData.appendChild(radar);
		return svgData;
	}
}

class data_card_tab {
	constructor () {
		this.page_name = "data_card";
	}
	async _add_svg_for_template(div,template_name) {
		const data_card = new player_template_data_card(template_name);
		const svg = await data_card.get_svg();
		div.appendChild(svg);
	}
	async show() {
		const page = document.createElement("div");
		const card = document.createElement("div");
		const sel = document.createElement("select");
		page.appendChild(sel);
		const templates = await gm_tool.get_all_player_templates();
		const this_card = this;
		const change_to = async function(template) {
			util.removeAllChildren(card);
			if (template == "*ALL*") {
				for (const template_name in templates) {
					if (templates.hasOwnProperty(template_name)) {
						this_card._add_svg_for_template(card,template_name);
					}
				}
			} else {
				this_card._add_svg_for_template(card,template);
			}
			page.appendChild(card);
		};

		sel.onchange = async function (option) {
			change_to(this.options[this.selectedIndex].value);
		};
		const new_option = function (name) {
			const option = document.createElement("option");
			option.value = name;
			option.textContent = name;
			sel.appendChild(option);
		};
		new_option("*ALL*");
		change_to("*ALL*");
		for (const template_name in templates) {
			if (templates.hasOwnProperty(template_name)) {
				new_option(template_name);
			}
		}
		return page;
	}
	get_button_text() {
		return "data card";
	}
}

class error_log_tab {
	constructor()  {
		this.page_name = "error_log";
	}
	get_button_text () {
		return error_logger.get_button_text();
	}
	async show () {
		const page = document.createElement("div");
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
	constructor () {
		this.page_name = "debug";
	}
	async show() {
		const page = document.createElement("div");
		const cache_details = document.createElement("table");
		page.appendChild(cache_details);
		const cache = await gm_tool.get_whole_cache();

		// show all of the sizes for the cache
		// TODO it might be nice to convert these to kb/mb
		const row = cache_details.insertRow();
		row.insertCell().appendChild(document.createTextNode("total size"));
		row.insertCell().appendChild(document.createTextNode(JSON.stringify(cache).length));
		for (const key in cache) {
			if (cache.hasOwnProperty(key)) {
				const row = cache_details.insertRow();
				row.insertCell().appendChild(document.createTextNode(key));
				row.insertCell().appendChild(document.createTextNode(JSON.stringify(cache[key]).length));
			}
		}
		return page;
	}
}

class home_tab {
	constructor() {
		this.page_name = "home";
	}
	async show() {
		const page = document.createElement("div");
		["reckless" , "safe", "cautious", "no_execs"].forEach( state => {
			const desc = {
				"reckless" : "intended for development, or generating the cache to run during other sessions",
				"safe" : "intended for saturday games, read only (any speed) or read / write with high confidence no issues",
				"cautious" : "quick read only, intended for the large games for example",
				"no_execs" : "intended for dev work, to confirm the cache contains everything",
			};
			const radio = document.createElement("input");
			radio.type = "radio";
			radio.name = "carefulness";
			radio.value = state;
			if (caution_level[state] == gm_tool.caution_level) {
				radio.checked = "checked";
			}
			radio.onclick = function () {
				gm_tool.set_caution_level(this.value);
			};
			page.appendChild(radio);
			page.appendChild(document.createTextNode(state+" - "+desc[state]));
			page.appendChild(document.createElement("br"));
		});
		
		const todo = document.createElement("div");
		page.appendChild(todo);
		const inner = "sadly right now this tool probably isnt useful unless you are able to ask starry questions<br>" +
			"at some point a home page probably should be .... I dont know .... useful to people<br>" +
			"but yet here we are, and I am going to use this as a todo list<br>" +
			"some sort of confirmation that the sandbox is loaded before running code in a random script would be nice<br>"+
			"It is likely this page is going to go horiffically wrong if a scenario is switched while this page is loaded, this needs thought as to how to manage it<br>"+
			"this really needs a way to save / load the cache, along with thought about how to fill the cache<br>"+
			"there is no check to see if the resouces directory is available from the web tool, this should be checked on this page<br>"+
			"some sort of consideration as to how to split the cache into scenario specific caches should happen before too long<br>";
		todo.innerHTML = inner;
		return page;
	}
}

class script_tab {
	constructor () {
		this.page_name = "script";
	}
	async show() {
		const page = document.createElement("div");
		const gmclick_button = document.createElement("button");
		gmclick_button.textContent = "get gmclick";
		const gmclick1 = this._gmclick1;
		gmclick_button.onclick = function () {
			gm_tool.call_www_function("get_gm_click1");
		};
		const show_gmclick_button = document.createElement("button");
		show_gmclick_button.textContent = "show gmclick";
		const gmclick2 = this._gmclick2;
		const results = document.createElement("div");
		show_gmclick_button.onclick = async function () {
			const loc = await gm_tool.call_www_function("get_gm_click2");
			if (loc) {
				results.innerHTML = loc.x + "," + loc.y;
			}
		};
		page.appendChild(gmclick_button);
		page.appendChild(show_gmclick_button);
		page.appendChild(results);
		page.appendChild(document.createTextNode("note this should be automatically updated, but currently isnt"));
		const input = document.createElement("textarea");
		input.style = "width : 100%";
		input.rows = "10";
		page.appendChild(input);
		page.appendChild(document.createElement("br"));
		const button = document.createElement("button");
		button.textContent = "max simplify";
		page.appendChild(button);
		const output = document.createElement("textarea");
		output.style = "width : 100%";
		output.rows = "10";
		page.appendChild(document.createElement("br"));
		page.appendChild(output);
		button.onclick = function () {
			let str = input.value;
			// this is kind of fragile
			// we implicitly are somewhat depending on the order that EE creates the export string
			// likewise we are assuming EE wont have newfunctions like setCallSignNewSuffix
			// mostly it should be simple to fix and even if it breaks it wont be at gm time

			// we are going to remove all of the functions we dont care about
			// we do this via changing them to rm then removing all of them in one regex
			str = str.replace(/:setBeamWeaponTurret/g,':rm');
			str = str.replace(/:setBeamWeapon/g,':rm');
			str = str.replace(/:setCallSign/g,':rm');
			str = str.replace(/:setRotationMaxSpeed/g,':rm');
			str = str.replace(/:setShortRangeRadarRange/g,':rm');
			str = str.replace(/:setWeaponStorageMax/g,':rm');
			str = str.replace(/:setWeaponStorage/g,':rm');
			str = str.replace(/:orderStandGround/g,':rm');
			str = str.replace(/:setWeaponTubeCount/g,':rm');
			str = str.replace(/:setTubeSize/g,':rm');
			str = str.replace(/:setShieldsMax/g,':rm');
			str = str.replace(/:setShields/g,':rm');
			str = str.replace(/:setHullMax/g,':rm');
			str = str.replace(/:setHull/g,':rm');
			str = str.replace(/:setImpulseMaxSpeed/g,':rm');
			str = str.replace(/:setWeaponTubeDirection/g,':rm');
			str = str.replace(/:setJumpDrive/g,':rm');
			str = str.replace(/:rm\([^)]*\)/g,'');
			str = str.replace(/^[ \t]*/gm,'');
			// now we sort

			let string_array = str.split("\n").sort();
			string_array = string_array.filter(line => line!="");

			const sorted_array = {
				CpuShip : [],
				other : [],
			};
			string_array.forEach(line => {
				if (line.match(/^CpuShip/)) {
					// this is wrong as its assuming any type name seen is a template, this may be fixable sandbox side for soft template
					//line = line.replace(/:setTemplate\("([^"]*)"\)(.*):setTypeName\(("[^"]*")\)/,"setTemplate($3)$2")
					line = line.replace(/CpuShip\(\)(.*):setTemplate\("([^"]*)"\)(.*):setTypeName\(("[^"]*")\)/,"ship_template[$4].create('Kraylor',$4)$3")
					sorted_array.CpuShip.push(line);
				} else {
					sorted_array.other.push(line);
				}
			});

			const str_output = sorted_array.CpuShip.join("\n").concat("\n",sorted_array.other.join("\n"))
			output.textContent = str_output;
		};
		// TODO some sort of mirroring code
		// TODO inner tabs?
		return page;
	}
}

class sat_tab {
	constructor () {
		this.page_name = "saturday";
		this._sat_start_lua = new lua_wrapper("in-progress/sat-start",caution_level.safe);
		this._sat_end_lua = new lua_wrapper("in-progress/sat-end",caution_level.safe);
		this._comm_lua = new lua_wrapper("in-progress/message_all_ship_sci",caution_level.safe);
	}
	async show() {
		const page = document.createElement("div");
		const comms = document.createElement("button");
		comms.textContent = "comms message";
		page.appendChild(comms);
		const _comm_lua = this._comm_lua;
		comms.onclick = function () {
			_comm_lua.run({msg : "All of the ships and stations near redshirt have been through an area of space where the warp readings where 500 ghz, it seems likely that this is the origin of the local kraylor attacks. your scanners have been  reconfigured to send out pings to measure the local warp frequency is. (check the 'other' tab on the science screen to activate it)"});
		};
		const start = document.createElement("button");
		start.textContent = "start";
		const _sat_start_lua = this._sat_start_lua;
		const end = document.createElement("button");
		const input = document.createElement("input"); // TODO long term this probably should convert with error checking
		input.value = 120;
		start.onclick = function () {
			_sat_start_lua.run({max_time : parseFloat(input.value), max_range : 5000, energy_cost : 100, no_eng_msg : "insufficient power", name : "active warp ping"});
		};
		input.setAttribute("type","number");
		page.appendChild(document.createElement("br"));
		page.appendChild(input);
		page.appendChild(document.createElement("br"));
		end.textContent = "end";
		const _sat_end_lua = this._sat_end_lua;
		end.onclick = function () {
			_sat_end_lua.run();
		};
		page.appendChild(start);
		page.appendChild(end);
		// above this is old, and probably wants intergrating elsewhere
		// even if its only into snippets
		return page;
	}
}

class rift_tab {
	constructor () {
		this.page_name = "rift";
	}
	async show() {
		const page = document.createElement("div");

		const rift = document.createElement("button");
		rift.textContent = "go";
		rift.onclick = function () {
			gm_tool.call_www_function("gm_click_wrapper",{fn : "subspace_rift",'max_radius' : 500,'max_time' : 1.5, 'on_end' : 'end_rift'});
		};
		page.appendChild(rift);

		// settings for
		// radius
		// what happens on contact to players
		// what happens on contacts to npc's
		// expansion rate
		return page;
	}
}

class in_dev_tab {
	constructor () {
		this.page_name = "in-dev";
		this._upload = new lua_wrapper("sandbox/update_system_debug",caution_level.reckless)
	}
	async show() {
		const page = document.createElement("div");
		const button = document.createElement("button");
		button.textContent = "run";
		console.log(await this._upload.run());
		button.onclick = function() {
			gm_tool.upload_to_script_storage_and_exec("print(\"atest\")");
		};
		page.appendChild(button);
		return page;
	}
}

class mirror_tool_tab {
	constructor() {
		this._mirror_tool = new lua_wrapper("in-progress/mirror-tool",caution_level.reckless);
		this.page_name = "mirror";
	}
	async show() {
		const page = document.createElement("div");
		const button = document.createElement("button");
		button.textContent = "enable";
		const _mirror_tool = this._mirror_tool;

		const input = document.createElement("textarea");
		input.style = "width : 100%";
		input.rows = "10";
		page.appendChild(input);
		page.appendChild(document.createElement("br"));


		button.onclick = function () {
			_mirror_tool.run();
		};
		page.appendChild(button);
		return page;
	}
}

class prebuilt_tab {
	constructor() {
		this.page_name = "prebuild";
	}
	async show() {
		const page = document.createElement("div");
		const base_list=["bigbase_01.txt", "diamond_01.txt", "icarus_style_01.txt", "missile_platform_base_01.txt" , "spiral_01.txt"];
		base_list.forEach(base => {
			console.log(base);
			const button = document.createElement("button");
			button.textContent = base;
			button.onclick = async function () {
				// I probably should cache this
				const lua = ee_server.fetch_file("lua/base snippets/"+base); // TODO WRONG
				gm_tool.upload_to_script_storage_and_exec(await lua);
			};
			page.appendChild(button);
		});
		page.appendChild(document.createElement("br"));

		const sat=["start0","start1","start2","start3","start4","start5"];
		sat.forEach(base => {
			const rift = document.createElement("button");
			rift.textContent = base;
			rift.onclick = function () {
				gm_tool.call_www_function(base);
			};
			page.appendChild(rift);
		});
		return page;
	}
}

class ui {
	constructor () {
		gm_tool.caution_level=caution_level.reckless;
		this._tabs = [
			new home_tab(),
			new data_card_tab(),
			new debug_tab(),
			new error_log_tab(),
			new sat_tab(),
			new rift_tab(),
			new script_tab(),
			new in_dev_tab(),
			new mirror_tool_tab(),
			new prebuilt_tab(),
		];
		this.update_button_list();
		this._last_url="";
	}
	update_button_list() {
		const tabs = document.getElementById("tab-buttons");
		util.removeAllChildren(tabs);
		this._tabs.forEach(tab => {
		const button = document.createElement("button");
			if ("get_button_text" in tab) {
				button.textContent = tab.get_button_text();
			} else {
				button.textContent = tab.page_name;
			}
			button.tab_class = tab;
			button.onclick = function(){
				gm_ui.switch_to(this.tab_class);
			};
			tabs.appendChild(button);
		});
	}
	async switch_to(tab) {
		try {
			const new_tab = await tab.show();
			util.removeAllChildren(document.getElementById("main-tab"));
			this._active_tab = tab;
			document.getElementById("main-tab").appendChild(new_tab);
			this.update_history();
		} catch (error) {
			error_logger.error(error);
		}
	}
	async switch_to_string(tab) {
		this._tabs.forEach (potentialTab => {
			if (potentialTab.page_name == tab) {
				gm_ui.switch_to(potentialTab);
			}
		});
	}
	update_history() {
		let url='index.html?';
		if (this._active_tab && this._active_tab.page_name != undefined) {
			url=url+"page="+this._active_tab.page_name;
		}
		if (this._last_url != url) {
			this.last_url = url;
			history.pushState(null, '', url);
		}
	}
	async load_page(page) {
		const args=page.substring(1).split('=');
		// this is super lazy and probably needs a better fix later
		this.switch_to_string("home");
		if (args.length == 2) {
			if (args[0] == "page") {
				this.switch_to_string(args[1]);
			}
		}
	}
}

const error_logger = new error_logger_class();
window.addEventListener("unhandledrejection", function(e) {
	error_logger.error(e.reason);
	e.preventDefault();
});

const gm_tool=new gm_tool_class();
gm_tool.init();

let gm_ui='';
window.onload=function () {
	gm_ui = new ui();
	gm_ui.load_page(window.location.search);
};
