---
layout: post
title: "Rethink event loop"
date: 2018-03-15
excerpt: "What the heck is the event loop anyway? – Philip Roberts"
tags:
- javascript
- event loop
comments: true
---

## Background

I have been working on JavaScript development for several years, the `event loop`, the basic but also abstract concept, I think I know it well after I went through Philip Roberts's great talk on JSConf EU 2014.

<iframe width="560" height="315" src="https://www.youtube.com/embed/8aGhZQkoFbQ?rel=0" frameborder="0" allow="autoplay; encrypted-media" allowfullscreen></iframe>

However, when I was reading [You don't know JavaScript](https://github.com/getify/You-Dont-Know-JS), I noticed there is [Job queue](https://github.com/getify/You-Dont-Know-JS/blob/master/async%20%26%20performance/ch1.md#jobs), it is similar to `task queue`, but the `jobs` will be executed after each `task`. What? Then I googled it, but more strange words entered my sight. `macrotask`, `microtask`. Ha? Maybe I don't understand event loop.

## Rethinking

![event-loop](https://user-images.githubusercontent.com/7512625/37471158-121bc6b4-28a4-11e8-8fce-181823d8de88.png)

<center><figcaption>Diagram from Philip Roberts's talk</figcaption></center>

In Philip's great talk, he demonstrated how the asynchronous callbacks (like setTimeout, I/O) been scheduled to the `callback queue` (aka `task queue`), but one thing was missed. `microtask`.

---

According to [whatwg#webappapis#event-loops](https://html.spec.whatwg.org/multipage/webappapis.html#event-loops),

- Event loop is used to coordinate events, user interaction, scripts, rendering, networking, and so forth
- There are two kinds of event loops: those for `browsing contexts`, and those for `workers`
- An event loop has one or more `task queues`
- **Each** event loop has a `microtask queue`
- If the JavaScript execution context stack is now empty, perform a microtask checkpoint

According to [whatwg#webappapis#integration-with-the-javascript-job-queue](https://html.spec.whatwg.org/multipage/webappapis.html#integration-with-the-javascript-job-queue),

- The JavaScript specification defines the JavaScript job and job queue abstractions in order to specify certain invariants about how `promise` operations execute with a clean JavaScript execution context stack and in a certain order
- When the JavaScript specification says to call the EnqueueJob abstract operation ... Queue a `microtask`

According to [ecma-262#sec-jobs-and-job-queues](http://ecma-international.org/ecma-262/6.0/index.html#sec-jobs-and-job-queues),

- Execution of a `Job` can be initiated only when there is no running `execution context` and the `execution context stack` is empty

According to [You don't know JavaScript#Event Loop](https://github.com/getify/You-Dont-Know-JS/blob/master/async%20%26%20performance/ch1.md#event-loop),

- Each iteration of this loop is called a `tick`. For each tick, if an event is waiting on the queue, it's taken off and executed. These events are your function callbacks

## Practise

Let's say we have such code snippet.

```javascript
setTimeout(function() {
  console.log('A');
}, 0);

new Promise(function executor(resolve) {
  console.log('B');
  resolve();
}).then(function() {
  console.log('C');
});

console.log('D');
```

The answer is `B D C A`.

### Steps

JS stack: []  
macrotask queue: []  
microtask queue: []   
output: []  

👇

JS stack: []  
macrotask queue: [console.log('A')]  
microtask queue: []  
output: []  

👇

JS stack: [console.log('B')]  
macrotask queue: [console.log('A')]  
microtask queue: []  
output: []  

---

Per [mdn](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise), the executor normally initiates some **asynchronous** work, so `console.log('B')` will be scheduled to JS stack to execute directly.

---

👇

JS stack: []  
macrotask queue: [console.log('A')]  
microtask queue: []  
output: [B]  

👇

JS stack: []  
macrotask queue: [console.log('A')]  
microtask queue: [console.log('C')]  
output: [B]  

👇

JS stack: [console.log('D')]  
macrotask queue: [console.log('A')]  
microtask queue: [console.log('C')]  
output: [B]

👇

JS stack: []  
macrotask queue: [console.log('A')]  
microtask queue: [console.log('C')]  
output: [B, D]

---

Now all synchronous code done and the JS stack is empty, so we are going to pick task from task queues. However, there is a confusing part. Should we pick task from macro queue first or micro queue first? The final output is `C A`, it seems like we pick task from micro queue first.

IMO, we could consider this case in two ways.

- Microtask queue is processed at the **end** of each macrotask, then you should treat whole script as a macrotask as well. In this way, our diagram will become

JS stack: [script]  
macrotask queue: [console.log('A')]  
microtask queue: [console.log('C')]  
output: [B, D]

At this time, pop script task out first, then execute microtasks.

- If you don't treat whole script as macrotask, you can think we will pick task from microtask queue when JS stack is empty at first time

---

👇

JS stack: [console.log('C')]  
macrotask queue: [console.log('A')]  
microtask queue: []  
output: [B, D]

👇

JS stack: []  
macrotask queue: [console.log('A')]  
microtask queue: []  
output: [B, D, C]

👇

JS stack: [console.log('A')]  
macrotask queue: []  
microtask queue: []  
output: [B, D, C]

👇

JS stack: []  
macrotask queue: []  
microtask queue: []  
output: [B, D, C, A]

It's done.

## Conclusion

- task (queue) === marcotask (queue)
- job (queue) ≈≈≈ microtask (queue) (Per You don't know JavaScript, they are same; but per ecma, there are two kinds of jobs, `ScriptJobs` and `PromiseJobs`, I don't understand `ScriptJobs` clearly, but the most important thing we should know is `promise.then` is one kind of `microtask`
- When JS stack (aka execution stack, or call stack) is empty, pick the oldest task from macro queue into JS stack to execute, then pick **ALL** tasks (or jobs) from micro queue to execute, then pick the oldest task from macro queue again
- macrotasks: script (whole script, you can consider it as main()), setTimeout, setInterval, setImmediate, I/O, UI rendering
- microtasks: process.nextTick, Promises, Object.observe, MutationObserver

## References

### Standard

- [https://html.spec.whatwg.org/multipage/webappapis.html#event-loops](https://html.spec.whatwg.org/multipage/webappapis.html#event-loops)
- [https://html.spec.whatwg.org/multipage/webappapis.html#integration-with-the-javascript-job-queue](https://html.spec.whatwg.org/multipage/webappapis.html#integration-with-the-javascript-job-queue)
- [http://ecma-international.org/ecma-262/6.0/index.html#sec-jobs-and-job-queues](http://ecma-international.org/ecma-262/6.0/index.html#sec-jobs-and-job-queues)

### Books

- [https://github.com/getify/You-Dont-Know-JS/blob/master/async%20%26%20performance/ch1.md#event-loop](https://github.com/getify/You-Dont-Know-JS/blob/master/async%20%26%20performance/ch1.md#event-loop)

### Articles

- [https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/)
