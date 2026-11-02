######## step4:分cluster######
sce.all.int #After
sce.all #Before
sce.all=sce.all.int
sce.all@active.assay
dim(sce.all)
#使用Seurat包中的FindNeighbors函数计算构建SNN图。
sce.all=FindNeighbors(sce.all, dims = 1:30, k.param = 60, prune.SNN = 1/15)

#先执行不同resolution 下的分群
#设置不同的分辨率，观察分群效果(选择哪一个？)
#在这里，jimmy老师把常用参数全部循环了一遍，再从中挑选最合适的
for (res in c(0.01, 0.05, 0.1, 0.2, 0.3, 0.5,0.8,1)) {
  sce.all=FindClusters(sce.all, graph.name = "CCA_snn", resolution = res, algorithm = 1)
}
apply(sce.all@meta.data[,grep("CCA_snn_res",colnames(sce.all@meta.data))],2,table)

#可以看出不同分辨率设置对于分群数量来说影响挺大，之前这里的分辨率我都没改过。（表情：0_0）

#低分辨率的分群情况。（0.01，0.1，0.2）
p1_dim=plot_grid(ncol = 3, DimPlot(sce.all, reduction = "umap", group.by = "CCA_snn_res.0.01") + 
                   ggtitle("louvain_0.01"), DimPlot(sce.all, reduction = "umap", group.by = "CCA_snn_res.0.1") + 
                   ggtitle("louvain_0.1"), DimPlot(sce.all, reduction = "umap", group.by = "CCA_snn_res.0.2") + 
                   ggtitle("louvain_0.2"))
ggsave(plot=p1_dim, filename="Dimplot_diff_resolution_low.pdf",width = 14)
ggsave(plot=p1_dim, filename="Dimplot_diff_resolution_low.png",width = 14)

#高分辨率的分群情况。（0.3，0.8，1）
p1_dim=plot_grid(ncol = 3, DimPlot(sce.all, reduction = "umap", group.by = "CCA_snn_res.0.8") + 
                   ggtitle("louvain_0.8"), DimPlot(sce.all, reduction = "umap", group.by = "CCA_snn_res.1") + 
                   ggtitle("louvain_1"), DimPlot(sce.all, reduction = "umap", group.by = "CCA_snn_res.0.3") + 
                   ggtitle("louvain_0.3"))
ggsave(plot=p1_dim, filename="Dimplot_diff_resolution_high.pdf",width = 18)
ggsave(plot=p1_dim, filename="Dimplot_diff_resolution_high.png",width = 18)


#使用clustree包来可视化不同分辨率下细胞在聚类群之间的分配。
### 参考：https://mp.weixin.qq.com/s/WRhMC3Ojy1GWYfLS_4vSeA
p2_tree=clustree(sce.all@meta.data, prefix = "CCA_snn_res.")
ggsave(plot=p2_tree, filename="Tree_diff_resolution.pdf",width = 8)
ggsave(plot=p2_tree, filename="Tree_diff_resolution.png",width = 8)

#接下来分析，按照分辨率为0.8进行 
sel.clust = "CCA_snn_res.0.8"
sce.all <- SetIdent(sce.all, value = sel.clust)
table(sce.all@active.ident) 
saveRDS(sce.all, "sce.all_int.rds")
rm(list=ls())
