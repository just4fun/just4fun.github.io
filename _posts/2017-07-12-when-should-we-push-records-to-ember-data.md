---
layout: post
title: "When should we push records to Ember Data?"
date: 2017-07-12
tag:
- JavaScript
- Ember
comments: true
---

Hey, I resovled an interesting defect these days about Ember data and I wanna share it to you all.

---

Let's say we have three kinds of components on the page.

![](https://user-images.githubusercontent.com/7512625/28120727-75de7e32-674b-11e7-9707-c40d79750209.png)

Regarding `overview-goals-month-goal.js`, its main content is an `input` element.

We have a computed property named `readonlyMonth` in top component `overview-goals.js` to indicate whether each input element is readonly or not, then pass it down.

{% highlight javascript %}
readonlyMonth: computed('data.months.1.goals.@each.goal-id', {
  get() {
    let thisMonthGoals = get(this, 'data.months.1.goals');

    return {
      0: true,
      1: false,
      2: isEmpty(thisMonthGoals) || thisMonthGoals.any((goal) => (!goal['goal-id']))
    };
  }
})
{% endhighlight %}

That said, for the first input, it's always readonly.   
For the second one, it's always editable.

As for third input element, it depends on whether second input has value, which means it always be readonly unless the second input has value.

<figure class="half">
  <img src="https://user-images.githubusercontent.com/7512625/28121513-ecf6a5ba-674d-11e7-9ddd-427266bf42e4.png">
  <img src="https://user-images.githubusercontent.com/7512625/28121514-ed03f6ca-674d-11e7-89df-3482e6825147.png">
  <figcaption>Once we gave second input any value, the third input will be editable immediately.</figcaption>
</figure>

---

For more background, I'd also like to share the data structure and API response.

`model/goal-reports.js`
{% highlight javascript %}
export default Model.extend({
  summary: attr(),
  months: attr(),

  goalMonths: computed('months.[]', {
    get() {
      let months = get(this, 'months');
      let goals = get(this, 'goals');

      months.forEach(month => {
        month.goals.forEach(goal => {
          goal.goal = goals.findBy('id', goal['goal-id']);
        });
      });

      return months;
    }
  }),

  goals: hasMany('goal')
});
{% endhighlight %}

`model/goal.js`
{% highlight javascript %}
export default Model.extend({
  goalValue: attr('number'),
  goalYear: attr(),
  goalMonth: attr()

  //...
});
{% endhighlight %}

If we give second input any value, `POST /api/goals` will be requested once we focused out.   
When we get 200, as we know, Ember data will fill `id` with API response.

**Here comes the question,** the goal record we saved is equal to the `goal.goal` in each months (see the computed property `goalMonths` in `goal-reports` model), why the third input still be readonly even `goalRecord.save()` successfully?
{: .notice}

---

Let's take a look at the API response when we access this page.

`GET /api/goal-reports`

![](https://user-images.githubusercontent.com/7512625/28122819-ea017228-6751-11e7-93d9-da6b8549235c.png)

There are two problems.

- `readonlyMonth` in top component hasn't been triggered

It's caused by that `goalMonths` in `goal-reports` model hasn't been triggered, b/c the length of `months` is same.   
Since `goalRecord.save()` successfully, there will be one more `goal` record in Ember data (we will discuss more about this in second problem), we should also add `goals.[]` to computed property `goalMonths`.

{% highlight javascript %}
goalMonths: computed('months.[]', 'goals.[]', {
  get() {
    let months = get(this, 'months');
    let goals = get(this, 'goals');

    months.forEach(month => {
      month.goals.forEach(goal => {
        goal.goal = goals.findBy('id', goal['goal-id']);
      });
    });

    return months;
  }
}),
{% endhighlight %}

- The `goal-id` of second object in `months` is empty.

In this case, even we add `goals.[]` to computed property `goalMonths`, `goalMonths` won't be triggered as well.

As we know, the `goals` of `goal-reports` model is returned in `included` field from API, that said even the new `goal` record with `id` has been update in store/Ember data, the `goals` in `goal-reprots` will still keep the same.

**Here come the resolution.**
{: .notice}

First we should create a closure action (`refreshReport`) in top component and pass it down.   
When `goalRecord.save()` successfully, the closure action should be triggered with the new `goal` record.

Then in top component,

{% highlight javascript %}
refreshReport(goal) {
  // first, get `goalsReport` from Ember data
  let goalReports = get(this, 'store').peekAll('goalsReport').get('firstObject');

  // then figure out which month (as known as `input` I mentioned)
  let month = goalReports.get('months').find(month => this.getMonth(month.date) === goal.get('goalMonth'));

  // check whether the input has no value before
  if (!month.goals[0]['goal-id']) {
    // set the `goal-id` with new `goal` record id
    set(month.goals[0], 'goal-id', goal.id);

    // push the new `goal` record into `goals` relationship in `goal-reports`.
    // then `goalMonths` will be triggered, and new `goal` will be filled in
    // each month, and also `readonlyMonth` will be re-triggered.
    goalReports.get('goals').pushObject(goal);
  }
}
{% endhighlight %}

Does it makes sense?