# README

## Useful Snippets

### Find all teams without participations

```ruby
teams = Team.where.missing(:participations)
```

### Find all kenshis without participations and purchases

```ruby
kenshis = Kenshi.where.missing(:participations, :purchases)
```

### Find all clubs without kenshis and users

```ruby
clubs = Club.where.missing(:kenshis, :users)
```

### Find shinpans in a category

```ruby
category = IndividualCategory.find 31

shinpans = Kenshi.joins(:participations).merge(category.participations).where(grade: %w[5Dan 6Dan 7Dan 8Dan])
```

### Reset pools for an IndividualCategory

```ruby
SmartPooler.new(category).set_pools
```
