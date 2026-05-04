# ============================================================
# Variables — EKS Module
# ============================================================

variable "cluster_name" {
  description = "Nama EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Versi Kubernetes untuk EKS cluster"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "ID VPC tempat EKS cluster akan dideploy"
  type        = string
}

variable "subnet_ids" {
  description = "List subnet IDs untuk EKS cluster dan node group (minimal 2 subnet di AZ berbeda)"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block VPC untuk security group rules"
  type        = string
}

variable "cluster_endpoint_private_access" {
  description = "Aktifkan akses private ke EKS API endpoint"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access" {
  description = "Aktifkan akses public ke EKS API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks yang diizinkan mengakses EKS API endpoint public"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "Tipe log EKS cluster yang akan dikumpulkan"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# ---- Node Group ----
variable "node_group_instance_types" {
  description = "Instance types untuk EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Jumlah node yang diinginkan"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Jumlah minimum node"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Jumlah maksimum node"
  type        = number
  default     = 4
}

variable "node_group_disk_size" {
  description = "Ukuran disk dalam GB untuk node group"
  type        = number
  default     = 20
}

variable "node_group_max_unavailable" {
  description = "Jumlah maksimum node yang tidak tersedia saat update"
  type        = number
  default     = 1
}

# ---- Add-on Versions ----
variable "coredns_addon_version" {
  description = "Version CoreDNS add-on"
  type        = string
  default     = null
}

variable "kube_proxy_addon_version" {
  description = "Version kube-proxy add-on"
  type        = string
  default     = null
}

variable "vpc_cni_addon_version" {
  description = "Version VPC CNI add-on"
  type        = string
  default     = null
}

# ---- Tags ----
variable "tags" {
  description = "Tags tambahan untuk semua resource EKS"
  type        = map(string)
  default     = {}
}
