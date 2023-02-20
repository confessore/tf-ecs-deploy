data "aws_vpc" "main" {
  id = local.vpc["id"]  # vpc-xx1x1x1x
}

data "aws_subnet" "subnets" {
  # availability_zones = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  for_each          = toset(local.vpc.availability_zones)
  vpc_id            = data.aws_vpc.main.id
  availability_zone = each.value
}