locals {
    vpc = {
        id = "" # vpc-xxxxxxxxxxxx
        availability_zones = [
            "us-east-2c",
            "us-east-2a",
            "us-east-2b"
        ]
    }
}

locals {
    alb = {
        name = "tf-alb"
        internal = false
        target_group = {
            name = "tf-alb-target-group"
            port = 80
            protocol = "HTTP"
        }
    }
}

locals {
    ecs = {
        cluster_name = "tf-ecs-cluster"
        service_name = "tf-ecs-service"
    }
}

locals {
  ecr = {
    repository_name = "tf-ecr-repo"
  }
}

locals {
    container = {
        name = "application"
        image = "registry.hub.docker.com/library/nginx:latest" # placeholder gets overriden by action
    }
}