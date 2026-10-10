import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
const js=fs.readFileSync("index_scripts/16.js","utf8");
const server=fs.readFileSync("backend/server.mjs","utf8");
test("1.0.22 LLM helpers exist",()=>{for(const n of ["nmLlmCfg","nmLlmBuildPayload","nmLlmSystemPrompt","nmLlmGenerate"] )assert.match(js,new RegExp(`function ${n}\\(`));});
test("LLM payload is structured and privacy-first",()=>{assert.ok(js.includes("namello-strategic-llm-v1"));assert.ok(js.includes("داده خام معاملات، نام حساب و یادداشت‌های شخصی"));assert.ok(js.includes("/v1/llm/strategic"));});
test("backend LLM proxy is authenticated and env-configured",()=>{assert.ok(server.includes("app.post('/v1/llm/strategic', auth"));assert.ok(server.includes("NAMELLO_LLM_API_KEY"));assert.ok(server.includes("NAMELLO_LLM_API_URL"));});
test("1.0.33 version contract",()=>{const v=JSON.parse(fs.readFileSync("version.json","utf8"));assert.equal(v.version,"1.0.33");assert.equal(v.versionCode,34);assert.ok(js.includes('NM_VERSION_NAME = "1.0.33"'));assert.ok(js.includes('NM_VERSION_CODE = 34'));});
