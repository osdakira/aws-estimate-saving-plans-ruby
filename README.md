# aws-estimate-saving-plans-ruby

Tool to calculate the price of aws saving plan.
Calculates the price applied by SavingPlan to a running on-demand instance.

## Installation

Clone the git repository and do a bundle install.

```
git clone git@github.com:osdakira/aws-estimate-saving-plans-ruby.git
cd aws-estimate-saving-plans-ruby
bundle install
```

## Run

Please log in so that you can use aws-sdk first.

```
bundle exec ruby main.rb
```

## Options

```
Usage: main [options]
        --region_code                default value: ap-northeast-1
        --region_abbr                default value: APN1
        --discounted_usage_type_suffix
                                     default value: -BoxUsage
        --product_family             default value: ComputeSavingsPlans
        --usage_type                 default value: ComputeSP:1yrAllUpfront
        --discounted_operation       default value: RunInstances
```

- usage_type: `ComputeSP:(1yr|3yr)(AllUpfront|PartialUpfront|NoUpfront)`
- discounted_usage_type_suffix: `AlwaysOnUsage|BoxUsage|DedicatedUsage|HighUsage|HostBoxUsage|HostUsage|ReservedHostUsage|SchedUsage|SpotUsage|UnusedBox`

## References

- Usage operation

Platform details | Usage operation **
-- | --
Linux/UNIX | RunInstances
Red Hat BYOL Linux | RunInstances:00g0
... | ...

https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/billing-info-fields.html

- Saving Plans

[Savings Plans Pricing – Amazon Web Services](https://aws.amazon.com/savingsplans/pricing/?nc1=h_ls)
