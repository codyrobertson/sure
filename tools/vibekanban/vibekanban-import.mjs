#!/usr/bin/env node
/**
 * VibeKanban Import Script
 *
 * Converts Sure Finance sprint task docs (docs/tasks/*.md) into
 * VibeKanban-compatible task format for bulk import via MCP server.
 *
 * Usage:
 *   node tools/vibekanban/vibekanban-import.mjs [--output json|mcp] [--sprint <name>]
 *
 * Options:
 *   --output json   Output raw JSON (default)
 *   --output mcp    Output MCP create_task commands
 *   --sprint <name> Process specific sprint (quickwins, goals, budget, ai)
 *   --subtasks      Include subtasks/UOWs
 */

import { readFileSync, readdirSync, writeFileSync } from 'fs';
import { join, basename } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const TASKS_DIR = join(__dirname, '..', '..', 'docs', 'tasks');

// Parse command line args
const args = process.argv.slice(2);
const outputFormat = args.includes('--output')
  ? args[args.indexOf('--output') + 1]
  : 'json';
const sprintFilter = args.includes('--sprint')
  ? args[args.indexOf('--sprint') + 1]
  : null;
const includeSubtasks = args.includes('--subtasks');

/**
 * Parse a sprint task markdown file
 */
function parseSprintDoc(filePath) {
  const content = readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const filename = basename(filePath, '.md');

  const sprint = {
    name: filename,
    title: '',
    tasks: []
  };

  let currentTask = null;
  let currentUOW = null;
  let section = null;
  let buffer = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Sprint title (# heading)
    if (line.startsWith('# ') && !sprint.title) {
      sprint.title = line.slice(2).trim();
      continue;
    }

    // Main task (## heading with Task/Quick Win/Sprint pattern)
    const taskMatch = line.match(/^## (?:Task |Quick Win |Sprint \d+: |T\d+[:.] )?(.*)/);
    if (taskMatch && !line.includes('Overview') && !line.includes('Summary')) {
      // Save previous task
      if (currentTask) {
        if (currentUOW) {
          currentUOW.description = buffer.join('\n').trim();
          currentTask.subtasks.push(currentUOW);
        }
        sprint.tasks.push(currentTask);
      }

      currentTask = {
        title: taskMatch[1].trim(),
        description: '',
        priority: 'P1',
        type: 'feature',
        subtasks: [],
        metadata: {}
      };
      currentUOW = null;
      buffer = [];
      section = 'task';
      continue;
    }

    // UOW/Subtask (### heading with UOW pattern)
    const uowMatch = line.match(/^### (UOW-[\d.]+|Step \d+)[:.]\s*(.*)/);
    if (uowMatch && currentTask) {
      // Save previous UOW
      if (currentUOW) {
        currentUOW.description = buffer.join('\n').trim();
        currentTask.subtasks.push(currentUOW);
      }

      currentUOW = {
        id: uowMatch[1],
        title: uowMatch[2].trim(),
        description: '',
        type: 'subtask'
      };
      buffer = [];
      section = 'uow';
      continue;
    }

    // Parse metadata lines
    if (line.startsWith('**Priority**:')) {
      const priority = line.match(/P\d/);
      if (priority && currentTask) currentTask.priority = priority[0];
      continue;
    }

    if (line.startsWith('**Type**:')) {
      const type = line.split(':')[1]?.trim();
      if (type && currentUOW) currentUOW.type = type;
      continue;
    }

    if (line.startsWith('**Dependencies**:')) {
      const deps = line.split(':')[1]?.trim();
      if (currentUOW) currentUOW.dependencies = deps;
      continue;
    }

    // Acceptance criteria
    if (line.includes('Acceptance') && line.includes(':')) {
      section = 'acceptance';
      continue;
    }

    // Collect description content
    if (section && !line.startsWith('---') && !line.startsWith('**Files')) {
      buffer.push(line);
    }
  }

  // Save final task/UOW
  if (currentUOW) {
    currentUOW.description = buffer.join('\n').trim();
    currentTask.subtasks.push(currentUOW);
  }
  if (currentTask) {
    sprint.tasks.push(currentTask);
  }

  return sprint;
}

/**
 * Format task for VibeKanban MCP create_task
 */
function formatForMCP(task, sprintName) {
  const description = [
    `**Sprint:** ${sprintName}`,
    `**Priority:** ${task.priority}`,
    '',
    task.description || '',
    '',
    task.subtasks.length > 0 ? '## Subtasks' : '',
    ...task.subtasks.map(s => `- [ ] ${s.id}: ${s.title}`)
  ].filter(Boolean).join('\n');

  return {
    tool: 'create_task',
    params: {
      projectPath: '/Users/Cody/code_projects/sure',
      title: task.title,
      description: description.trim()
    }
  };
}

/**
 * Format subtask for VibeKanban MCP
 */
function formatSubtaskForMCP(subtask, parentTitle, sprintName) {
  return {
    tool: 'create_task',
    params: {
      projectPath: '/Users/Cody/code_projects/sure',
      title: `${subtask.id}: ${subtask.title}`,
      description: [
        `**Parent:** ${parentTitle}`,
        `**Sprint:** ${sprintName}`,
        `**Type:** ${subtask.type}`,
        subtask.dependencies ? `**Dependencies:** ${subtask.dependencies}` : '',
        '',
        subtask.description
      ].filter(Boolean).join('\n')
    }
  };
}

// Main execution
const files = readdirSync(TASKS_DIR).filter(f => f.endsWith('.md'));
const allSprints = [];

for (const file of files) {
  const sprintName = basename(file, '.md').replace('-sprint-1', '').replace('sprint-1', '');

  // Apply filter if specified
  if (sprintFilter && !sprintName.includes(sprintFilter)) {
    continue;
  }

  const sprint = parseSprintDoc(join(TASKS_DIR, file));
  allSprints.push(sprint);
}

// Output based on format
if (outputFormat === 'mcp') {
  const commands = [];

  for (const sprint of allSprints) {
    console.log(`\n# Sprint: ${sprint.title}`);
    console.log(`# Tasks: ${sprint.tasks.length}\n`);

    for (const task of sprint.tasks) {
      const cmd = formatForMCP(task, sprint.name);
      commands.push(cmd);
      console.log(`# Task: ${task.title}`);
      console.log(JSON.stringify(cmd, null, 2));
      console.log('');

      if (includeSubtasks) {
        for (const subtask of task.subtasks) {
          const subCmd = formatSubtaskForMCP(subtask, task.title, sprint.name);
          commands.push(subCmd);
          console.log(`# Subtask: ${subtask.title}`);
          console.log(JSON.stringify(subCmd, null, 2));
          console.log('');
        }
      }
    }
  }

  // Write commands file
  writeFileSync(
    join(__dirname, 'vibekanban-tasks.json'),
    JSON.stringify(commands, null, 2)
  );
  console.log(`\nWrote ${commands.length} tasks to tools/vibekanban/vibekanban-tasks.json`);

} else {
  // JSON output
  const output = {
    project: 'Sure Finance',
    projectPath: '/Users/Cody/code_projects/sure',
    generatedAt: new Date().toISOString(),
    sprints: allSprints,
    summary: {
      totalSprints: allSprints.length,
      totalTasks: allSprints.reduce((sum, s) => sum + s.tasks.length, 0),
      totalSubtasks: allSprints.reduce((sum, s) =>
        sum + s.tasks.reduce((tSum, t) => tSum + t.subtasks.length, 0), 0
      )
    }
  };

  console.log(JSON.stringify(output, null, 2));

  // Write to file
  writeFileSync(
    join(__dirname, 'vibekanban-export.json'),
    JSON.stringify(output, null, 2)
  );
  console.log(`\nWrote export to tools/vibekanban/vibekanban-export.json`);
}
