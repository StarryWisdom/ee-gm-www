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
		if (this.callback) {
			this.callback();
		}
	}
	on_error_call(callback) {
		this.callback = callback;
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
				fixed_response_text = fixed_response_text.replace(/\t/g,'\\t');
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

// get template data that cant be fetched from a live object of that type
// it may be possible with time and work for this to be removed
// this would require EE scripting to be exapanded
class get_extra_template_data{
	constructor (cache) {
		this._cache = cache;
		// this needlessly fills the cache with the lua
		// this could be fixed, but is not currently important
		this._cache.set("template_data",this.resolve());
	}
	async resolve() {
		const raw = await gm_tool.call_www_function("getExtraTemplateData");
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

// at the moment this is rather jumbled between getting the soft template and the actual template
// at some point this will probably be cleared up, but at the moment it is something to keep in mind
class get_player_soft_template {
	constructor(cache) {
		this._cache = cache;
	}
	async _postprocess(raw) {
		raw = await raw;
		// get data needed for the all the postprocessing
		// TODO needs to handle ships with their typename changed
		// this will break almost all of xanstas soft template ships
		const template = (await gm_tool.get_extra_template_data.get())[raw.TypeName];
		const model = gm_tool.get_model_data()[template.Model];

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
			this._cache.set(cache_entry,this._postprocess(gm_tool.call_www_function("get_playership_softtemplate",{ship_template : template_name})));
		}
		return this._cache.get(cache_entry);
	}
}

class gm_tool_class {
	// this needs to be called before any other members are used
	async init() {
		this._ee_cache = new data_cache();
		// set up all of the classes for server requesting data
		this.get_extra_template_data = new get_extra_template_data(this._ee_cache);
		this.get_player_soft_template = new get_player_soft_template(this._ee_cache);

		await this.exec_lua(await gm_tool.cache_get_lua("www_gm_tools"),"www_gm_tools")

		this._model_data = await this._model_data_resolve();
		this._soft_cpuship_templates = await this._cpuship_data_resolve();

		this._function_descriptions = await this.call_www_function("get_descriptions");
	}
	// get all of the model data
	// mainly used for infomation like beam port starts, scale of the model etc
	// the things we want out of it may be possible to expose via new EE scripting
	// in which case this may stop needing to exist
	async _model_data_resolve() {
		const models = ee_server.convert_lua_json_to_array(await gm_tool.call_www_function("getModelData"));
		const ret = {};
		models.forEach(model => {
			model.BeamPosition=ee_server.convert_lua_json_to_array(model.BeamPosition);
			const name = model.Name;
			delete model.Name;
			ret[name] = model;
		});
		return ret;
	}
	async _cpuship_data_resolve() {
		return ee_server.convert_lua_json_to_array(await(gm_tool.call_www_function("getCpushipSoftTemplates")));
	}
	get_cpuship_data() {
		return this._soft_cpuship_templates;
	}
	get_model_data() {
		return this._model_data;
	}
	get_prebuilt() {
		// this wants to change to support local storage at some point soon
		return prebuilt;
	}
	// convert argument into something to be merged with a string for call_www_function
	// main uses are escaping strings, flattening object
	_call_convert_to_string(arg) {
		if (typeof(arg) === "string") {
			return '"' + arg.replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/\r/g,'').replace(/\n/g,'\\n') + '"';
		} else if (Array.isArray(arg)) {
			let ret = "{";
			let first = true;
			arg.forEach( i => {
				if (first) {
					first = false;
				} else {
					ret += ",";
				}
				ret += this._call_convert_to_string(i);
			});
			ret += "}";
			return ret;
		} else if (typeof(arg)=="object") {
			let first = true;
			let ret = "{";
			for (const key in arg) {
				if (arg.hasOwnProperty(key)) {
					if (first) {
						first = false;
					} else {
						ret += ",";
					}
					ret += key + " = " + this._call_convert_to_string(arg[key]);
				}
			}
			ret += "}";
			return ret;
		} else {
			return arg;
		}
	}
	async direct_www_call(name) {
		let code = "return getScriptStorage()._cuf_gm."+name+"(";
		for (let i=1; i< arguments.length; i++) {
			code += this._call_convert_to_string(arguments[i]);
			if (i+1!=arguments.length) {
				code += ",";
			}
		}
		code += ")";
		return this.exec_lua(code,"");
	}
	async call_www_function(name,args = {}) {
		let code = "return getScriptStorage()._cuf_gm.indirect_call(";
		args.call=name;
		code +=  this._call_convert_to_string(args);
		code += ")";
		return this.exec_lua(code,"");
	}
	async upload_to_script_storage_and_exec(str) {
		const max_length = ee_server.max_exec_length/2;// we are just going to be cautious on the chunks we upload rather than check the exact number of chars
		let i = 0;
		let parts = [];
		for (;i*max_length<=str.length;i++) {
			parts[i+1]=str.slice(i*max_length,(i+1)*max_length);
		}
		const id = await this.direct_www_call("webUploadStart",i);
		for (let l = 1; l<=i ;l++) {
			parts[l] = this.direct_www_call("webUploadSegment",id,l,parts[l]);
		}
		await Promise.all(parts);
		// TODO we should clear old strings
		return this.direct_www_call("webUploadEndAndRunAndFree",id);
	}
	async get_whole_cache() {
		return this._ee_cache.get_whole_cache();
	}
	async cache_get_lua(filename) {
		const cache_name = filename+".lua";
		if (!this._ee_cache.has_key(cache_name)) {
			this._ee_cache.set(cache_name,ee_server.fetch_file(cache_name));
		}
		return this._ee_cache._cache[cache_name];
	}
	make_edit_div_for_function(function_name) {
		const function_div = document.createElement("div");
		// this needs improvement
		const args = this._function_descriptions[function_name];

		const title = document.createElement("a");
		title.textContent = function_name + " settings";
		if (args.this != undefined) {
			title.title = args.this[1];
		}
		function_div.appendChild(title);
		function_div.appendChild(document.createElement("br"));

		function_div.function_name = function_name;
		function_div.build_call = function (function_name) {
			const call = {};
			for (const p in function_div.params) {
				if (function_div.params.hasOwnProperty(p)) {
					call[p] = function_div.params[p].getValue();
				}
			}
			call.call = function_name;
			return call;
		}

		// a table of each argument, element is an object with the following properties
		// each element needs a getValue, setValue, removeThis function
		function_div.params = {};
		for (const arg_num in args) {
			if (args.hasOwnProperty(arg_num)) {
				if (arg_num == "this") {
					continue;
				}
				const arg = args[arg_num];
				const arg_name = arg[1];
				const arg_type = arg[2];
				const arg_default = arg[3];
				const div = document.createElement("div");
				function_div.appendChild(div);

				const name = document.createElement("a");
				name.textContent = arg_name;
				div.appendChild(name);

				const param = {};
				function_div.params[arg_name] = param;
				function_div.params[arg_name].removeThis = function () {
					function_div.removeChild(div);
				}

				if (arg_type == "number") {
					const input = document.createElement("input");
					param.getValue = function () {
						return parseFloat(input.value);
					};
					param.setValue = function (value) {
						input.value = value;
					};
					input.setAttribute("type","number");
					if (arg.min != undefined) {
						input.min = arg.min;
					}
					if (arg.max != undefined) {
						input.max = arg.max;
					}
					div.appendChild(input);
				} else if(arg_type == "string") {
					const input = document.createElement("input");
					param.getValue = function () {
						return input.value;
					};
					param.setValue = function (value) {
						input.value = value;
					};
					div.appendChild(input);
				} else if (arg_type == "npc_ship") {
					const input = document.createElement("select");
					this.get_cpuship_data().forEach(k => {
							const name = k.gm_name;
							const opt = document.createElement("option");
							opt.value = name;
							opt.innerHTML = name;
							input.appendChild(opt);
					});
					param.getValue = function () {
						return input.value;
					};
					param.setValue = function (value) {
						input.value = value;
					};
					div.appendChild(input);
				} else if (arg_type == "position") {
					const get_value = document.createElement("button");
					const got = document.createTextNode("");
					get_value.textContent = "last fetched click";
					get_value.onclick = async function () {
						const loc = await gm_tool.call_www_function("get_gm_click2");
						if (loc) {
							function_div.params[arg_name] = {
								getValue : function () {
									return loc;
								}
							};
							got.data = loc.x + "," + loc.y;
						}
					}
					div.appendChild(get_value);
					div.appendChild(got);

					const run_via_click = document.createElement("button");
					param.getValue = function () { // todo handle error
					};
					run_via_click.textContent = "run via gmClick";
					run_via_click.onclick = function () {
						const call = function_div.build_call(function_name);
						delete call[arg_name];
						gm_tool.call_www_function("gm_click_wrapper",{args : call});
					};
					div.appendChild(run_via_click);
				} else if (arg_type == "function" || arg_type == "indirect_function") {
					// note firstChild is kind of broken with multiple functions
					const td2 = document.createElement("td");
					const table = document.createElement("table");
					const tr = document.createElement("tr");
					const td1 = document.createElement("td");
					table.appendChild(tr);
					tr.appendChild(td1);
					tr.appendChild(td2);
					div.appendChild(table);
					param.setValue = function (values) {
						if (td2.firstChild) {
							td2.removeChild(td2.firstChild);
						}
						const function_edit = gm_tool.make_edit_div_for_function(values.call);
						td2.appendChild(function_edit);
						// todo this is bad / wrong

						for (const arg in values) {
							if (values.hasOwnProperty(arg)) {
								if (arg!="call") {
									function_edit.params[arg].setValue(values[arg]);
								}
							}
						}
						if (args[arg_num].ui_suppress != undefined) {
							ee_server.convert_lua_json_to_array(arg.ui_suppress).forEach(arg => {
								if (function_edit.params[arg] != undefined) {
									function_edit.params[arg].removeThis();
								}
							});
						}
						function_edit.remove_go_button();
					}
					param.getValue = function ()
					{
						return td2.firstChild.build_call(td2.firstChild.function_name);
					}
				} else {
					error_logger.error("unknown type requested to be displayed");
				}
				// todo description of the arg
				// todo title text
				if (arg_default) {
					param.setValue(arg_default);
				}
			}
		}


		// todo consider how to manage multiple positions
		const run = document.createElement("button");
		run.textContent = "go";
		run.onclick = function () {
			gm_tool.call_www_function(function_name,function_div.build_call());
		};
		function_div.remove_go_button = function () {
			function_div.removeChild(run);
		};
		function_div.appendChild(run);
		return function_div;
	}
	async exec_lua(code,filename) {
		if (code.length <= ee_server.max_exec_length) {
			return ee_server.exec(code,filename);
		} else {
			return this.upload_to_script_storage_and_exec(code);
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
		const inner = "sadly right now this tool probably isnt useful unless you are able to ask starry questions<br>" +
			"at some point a home page probably should be .... I dont know .... useful to people<br>" +
			"but yet here we are, and I am going to use this as a todo list<br>" +
			"some sort of confirmation that the sandbox is loaded before running code in a random script would be nice<br>"+
			"It is likely this page is going to go horiffically wrong if a scenario is switched while this page is loaded, this needs thought as to how to manage it<br>"+
			"Likewise there probably should be checks that www_gm_tools.lua loads correctly<br>"+
			"Also some sort of check for non sandbox scripts needs adding, even if it is just ensuring it dies fast<br>"+
			"this really needs a way to save / load the cache, along with thought about how to fill the cache<br>"
			"splitting of caches between script and non script code should be considered at some point<br>"+
			"there is no check to see if the resouces directory is available from the web tool, this should be checked on this page<br>"+
			"some sort of consideration as to how to split the cache into scenario specific caches should happen before too long<br>"+
			"something needs to be done with script restarts, this probably needs engine changes<br>"+
			"related to that - looking into script changing without having to reload the page would be good<br>"+
			"in my old notes I have something saying spaces dont work for page names - url related? - I need to look into it<br>"+
			"In general some sort of release build for nebula servers is needed<br>";
		page.innerHTML = inner;
		return page;
	}
}

class script_tab {
	constructor () {
		this.page_name = "script";
	}
	async show() {
		const page = document.createElement("div");
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
			str = str.replace(/:setImpulseMaxReverseSpeed/g,':rm');
			str = str.replace(/:setWeaponTubeDirection/g,':rm');
			str = str.replace(/:setJumpDrive/g,':rm');
			str = str.replace(/:orderRoaming/g,':rm');
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
					line = line.replace(/CpuShip\(\)(.*):setTemplate\("([^"]*)"\)(.*):setTypeName\(("[^"]*")\)/,"ship_template[$4].create('Kraylor',$4)$3");
					sorted_array.CpuShip.push(line);
				} else {
					sorted_array.other.push(line);
				}
			});

			const str_output = sorted_array.CpuShip.join("\n").concat("\n",sorted_array.other.join("\n"));
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
	}
	async show() {
		const page = document.createElement("div");
		const comms = document.createElement("button");
		comms.textContent = "comms message";
		page.appendChild(comms);
		comms.onclick = function () {
			gm_tool.call_www_function("old_test_comms",{msg : "All of the ships and stations near redshirt have been through an area of space where the warp readings where 500 ghz, it seems likely that this is the origin of the local kraylor attacks. your scanners have been  reconfigured to send out pings to measure the local warp frequency is. (check the 'other' tab on the science screen to activate it)"});
		};
		const start = document.createElement("button");
		start.textContent = "start";
		const end = document.createElement("button");
		const input = document.createElement("input"); // TODO long term this probably should convert with error checking
		input.value = 120;
		start.onclick = function () {
			gm_tool.call_www_function("old_test_start",{max_time : parseFloat(input.value), max_range : 5000, energy_cost : 100, no_eng_msg : "insufficient power", name : "active warp ping"});
		};
		input.setAttribute("type","number");
		page.appendChild(document.createElement("br"));
		page.appendChild(input);
		page.appendChild(document.createElement("br"));
		end.textContent = "end";
		end.onclick = function () {
			gm_tool.call_www_function("old_test_end");
		};
		page.appendChild(start);
		page.appendChild(end);
		// above this is old, and probably wants intergrating elsewhere
		// even if its only into snippets
		return page;
	}
}

class callback_tab {
	constructor () {
		this.page_name = "callbacks";
	}
	async show() {
		const page = document.createElement("div");
		// this is kind of digging into gm_tool more than it should
		const keys = Object.keys(gm_tool._function_descriptions);
		keys.sort();
		keys.forEach(fun_name => {
			if (gm_tool._function_descriptions.hasOwnProperty(fun_name)) {
				const inner_div = document.createElement("div");
				page.appendChild(inner_div);
				inner_div.appendChild(gm_tool.make_edit_div_for_function(fun_name));
				page.appendChild(document.createElement("hr"));
			}
		});
		return page;
	}
}

class update_debug_in_dev {
	constructor () {
		this.page_name = "update-dev";
		this._page;
	}
	async show() {
		const page = document.createElement("div");
		this._page = page;
		const button = document.createElement("button");
		button.textContent = "run";
		const update = this;
		button.onclick = async function() {
			update.update_page(await gm_tool.call_www_function("getUpdateData"));
		};
		page.appendChild(button);
		return page;
	}
	update_page(data) {
		data = ee_server.convert_lua_json_to_array(data);
		const page = this._page;
		const button = page.firstChild;
		util.removeAllChildren(page);
		page.appendChild(button);

		const table = document.createElement("table");
		page.appendChild(table);

		console.log(data);
		data.forEach(update_obj => {
			const tr = document.createElement("tr");
			table.appendChild(tr)
			let td = document.createElement("td");
			tr.appendChild(td)
			console.log(update_obj);
			td.innerHTML = update_obj.description + "(" + update_obj.id + ")";
			td = document.createElement("td");
			tr.appendChild(td)
		});
	}
}

class dev_tab {
	constructor(parent) {
		this.page_name = "development"
		this.parent = parent;
		if (parent.update_history == undefined) {
			throw new Error("Parent for dev_tab is missing required class members.");
		}
	}
	async show (sub_page) {
		const page = document.createElement("div");
		this._tabbed = new tabbed_ui(this,"subpage",page);
		this._tabbed.add_tab(new update_debug_in_dev(this));
		this._tabbed.add_tab(new mirror_tool_tab(this));
		this._tabbed.add_tab(new data_card_tab(this));
		this._tabbed.add_tab(new debug_tab(this));
		if (sub_page && sub_page["subpage"]) {
			const subpage = sub_page.subpage;
			delete sub_page.subpage;
			this._tabbed.switch_to_string(subpage,sub_page);
		}
		return page;
	}
	update_history(sub_url) {
		this.parent.update_history("page="+this.page_name+"&"+sub_url);
	}
}

class obsolete_soon_tab {
	constructor(parent) {
		this.page_name = "obsolete"
		this.parent = parent;
		if (parent.update_history == undefined) {
			throw new Error("Parent for dev_tab is missing required class members.");
		}
	}
	async show (sub_page) {
		const page = document.createElement("div");
		this._tabbed = new tabbed_ui(this,"subpage",page);
		this._tabbed.add_tab(new script_tab(this));
		this._tabbed.add_tab(new sat_tab(this));
		this._tabbed.add_tab(new prebuilt_tab(this));
		if (sub_page && sub_page["subpage"]) {
			const subpage = sub_page.subpage;
			delete sub_page.subpage;
			this._tabbed.switch_to_string(subpage,sub_page);
		}
		return page;
	}
	update_history(sub_url) {
		this.parent.update_history("page="+this.page_name+"&"+sub_url);
	}
}

class mirror_tool_tab {
	constructor() {
		this.page_name = "mirror";
	}
	async show() {
		const page = document.createElement("div");
		const button = document.createElement("button");
		button.textContent = "enable";

		const input = document.createElement("textarea");
		input.style = "width : 100%";
		input.rows = "10";
		page.appendChild(input);
		page.appendChild(document.createElement("br"));


		button.onclick = function () {
			gm_tool.call_www_function("mirror_in_dev")
		};
		page.appendChild(button);
		return page;
	}
}

class prebuilt_tab {
	constructor() {
		this.page_name = "prebuilt";
	}
	async show() {
		const page = document.createElement("div");
		// this isnt needed any more?
		// think about removal
		const base_list=["bigbase_01.txt", "diamond_01.txt", "icarus_style_01.txt", "missile_platform_base_01.txt" , "spiral_01.txt"];
		base_list.forEach(base => {
			const button = document.createElement("button");
			button.textContent = base;
			button.onclick = async function () {
				// I probably should cache this
				const lua = ee_server.fetch_file("base snippets/"+base); // TODO WRONG
				gm_tool.upload_to_script_storage_and_exec(await lua);
			};
			page.appendChild(button);
		});
		page.appendChild(document.createElement("br"));

		gm_tool.get_prebuilt().forEach(base => {
			const run = document.createElement("button");
			run.textContent = base.name;
			run.onclick = function () {
				gm_tool.call_www_function("call_list",{call_list : base.call_list});
			};
			page.appendChild(run);
		});
		return page;
	}
}

class tabbed_ui {
	constructor(parent,url_name,my_div) {
		this.parent = parent;
		this._my_div = my_div;
		this._button_div = document.createElement("div"); // this orignally was style="float: left, clear:none" , this may be uneeded however
		my_div.appendChild(this._button_div);
		this._tabs = [];
		if (parent.update_history == undefined) {
			throw new Error("Parent for tabbed ui is missing required class members.");
		}
		this._url_name = url_name;
	}
	add_tab(tab) {
		if (tab.page_name == undefined) {
			throw new Error("Tab for tabbed ui is missing required class member.");
		}
		this._tabs.push(tab);
		this.update_button_list();
	}
	update_button_list() {
		util.removeAllChildren(this._button_div);
		this._tabs.forEach(tab => {
			const button = document.createElement("button");
			if ("get_button_text" in tab) {
				button.textContent = tab.get_button_text();
			} else {
				button.textContent = tab.page_name;
			}
			const tabbed_element = this;
			button.onclick = function(){
				tabbed_element.switch_to_string(tab.page_name);
			};
			this._button_div.appendChild(button);
		});
	}
	async switch_to_string(tab,show_params) {
		try {
			this._tabs.forEach (potentialTab => {
				if (potentialTab.page_name == tab) {
					const tabbed = this;
					potentialTab.show(show_params).then(function(page) {
						if (tabbed.page != undefined) {
							tabbed._my_div.removeChild(tabbed.page);
						}
						tabbed.page = page;
						tabbed._my_div.appendChild(page);
						tabbed.parent.update_history(tabbed._url_name+"="+potentialTab.page_name);
					});
					return;
				}
			});
		} catch (error) {
			error_logger.error(error);
		}
	}
}

class ui {
	constructor () {
		this._last_url="";
		this._tabbed = new tabbed_ui(this,"page",document.getElementById("main-tab"));
		this._tabbed.add_tab(new home_tab(this));
		this._tabbed.add_tab(new callback_tab(this));
		this._tabbed.add_tab(new dev_tab(this));
		this._tabbed.add_tab(new obsolete_soon_tab(this));
		this._has_error_tab = false;
		const tmp = this;
		error_logger.on_error_call(function () {tmp.error_callback();});
	}
	async load_page(page) {
		let keys = {};
		const search = new URLSearchParams(page);
		for (const k of search) {
			keys[k[0]] = search.get(k[0]);
		}
		if (keys["page"]) {
			const page = keys["page"]
			delete keys.page;
			this._tabbed.switch_to_string(page,keys);
		}
	}
	update_history(sub_url) {
		const url = 'index.html?'+sub_url;
		if (this._last_url != url) {
			this._last_url = url;
			document.title = url;
			history.pushState(null, '', url);
		}
	}
	update_button_list() {
		this._tabbed.update_button_list();
	}
	error_callback() {
		if (!this._has_error_tab) {
			this._tabbed.add_tab(new error_log_tab(this));
			this._has_error_tab = true;
		}
		this.update_button_list();
	}
}

const error_logger = new error_logger_class();
window.addEventListener("unhandledrejection", function(e) {
	error_logger.error(e.reason);
	e.preventDefault();
});

const gm_tool=new gm_tool_class();

window.onload = async function () {
	await gm_tool.init();
	const gm_ui = new ui();
	gm_ui.load_page(window.location.search);
};
