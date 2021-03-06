cimport numpy as cnp

cimport pcl_defs as cpp

from cython.operator import dereference as deref
from libcpp.string cimport string
from libcpp cimport bool

cdef extern from "minipcl.h":
    void mpcl_compute_normals(cpp.PointCloud_t, int ksearch, cpp.PointNormalCloud_t)

SAC_RANSAC = cpp.SAC_RANSAC

SACMODEL_PLANE = cpp.SACMODEL_PLANE
SACMODEL_SPHERE = cpp.SACMODEL_SPHERE
SACMODEL_CYLINDER = cpp.SACMODEL_CYLINDER

cdef class Segmentation:
    cdef cpp.SACSegmentation_t *me
    def __cinit__(self):
        self.me = new cpp.SACSegmentation_t()
    def __dealloc__(self):
        del self.me

    def segment(self):
        cdef cpp.PointIndices ind
        cdef cpp.ModelCoefficients coeffs
        self.me.segment (ind, coeffs)
        return [ind.indices[i] for i in range(ind.indices.size())],\
               [coeffs.values[i] for i in range(coeffs.values.size())]

    def set_optimize_coefficients(self, bool b):
        self.me.setOptimizeCoefficients(b)
    def set_model_type(self, cpp.SacModel m):
        self.me.setModelType(m)
    def set_method_type(self, int m):
        self.me.setMethodType (m)
    def set_distance_threshold(self, float d):
        self.me.setDistanceThreshold (d)

#yeah, I can't be bothered making this inherit from SACSegmentation, I forget the rules
#for how this works in cython templated extension types anyway
cdef class SegmentationNormal:
    cdef cpp.SACSegmentationNormal_t *me
    def __cinit__(self):
        self.me = new cpp.SACSegmentationNormal_t()
    def __dealloc__(self):
        del self.me

    def segment(self):
        cdef cpp.PointIndices ind
        cdef cpp.ModelCoefficients coeffs
        self.me.segment (ind, coeffs)
        return [ind.indices[i] for i in range(ind.indices.size())],\
               [coeffs.values[i] for i in range(coeffs.values.size())]

    def set_optimize_coefficients(self, bool b):
        self.me.setOptimizeCoefficients(b)
    def set_model_type(self, cpp.SacModel m):
        self.me.setModelType(m)
    def set_method_type(self, int m):
        self.me.setMethodType (m)
    def set_distance_threshold(self, float d):
        self.me.setDistanceThreshold (d)
    def set_optimize_coefficients(self, bool b):
        self.me.setOptimizeCoefficients (b)
    def set_normal_distance_weight(self, float f):
        self.me.setNormalDistanceWeight (f)
    def set_max_iterations(self, int i):
        self.me.setMaxIterations (i)
    def set_radius_limits(self, float f1, float f2):
        self.me.setRadiusLimits (f1, f2)

cdef class PointCloud:
    cdef cpp.PointCloud[cpp.PointXYZ] *thisptr
    def __cinit__(self):
        self.thisptr = new cpp.PointCloud[cpp.PointXYZ]()
    def __dealloc__(self):
        del self.thisptr
    property width:
        def __get__(self): return self.thisptr.width
    property height:
        def __get__(self): return self.thisptr.height
    property size:
        def __get__(self): return self.thisptr.size()
    property is_dense:
        def __get__(self): return self.thisptr.is_dense

    def from_array(self, cnp.ndarray[cnp.float32_t, ndim=2] arr not None):
        assert arr.shape[1] == 3

        cdef int npts = arr.shape[0]
        self.resize(npts)
        self.thisptr.width = npts
        self.thisptr.height = 1

        cdef i = 0
        while i < npts:
            self.thisptr.at(i).x = arr[i,0]
            self.thisptr.at(i).y = arr[i,1]
            self.thisptr.at(i).z = arr[i,2]
            i += 1

    def from_list(self, _list):
        assert len(_list)
        assert len(_list[0]) == 3

        cdef npts = len(_list)
        self.resize(npts)
        self.thisptr.width = npts
        self.thisptr.height = 1
        for i,l in enumerate(_list):
            self.thisptr.at(i).x = l[0]
            self.thisptr.at(i).y = l[1]
            self.thisptr.at(i).z = l[2]

    def resize(self, int x):
        self.thisptr.resize(x)

    def get_point(self, int row, int col):
        #grr.... the following doesnt compile to valid
        #cython.. so just take the perf hit
        #cdef PointXYZ &p = self.thisptr.at(x,y)
        cdef x = self.thisptr.at(row,col).x
        cdef y = self.thisptr.at(row,col).y
        cdef z = self.thisptr.at(row,col).z
        return x,y,z
        
    def __getitem__(self, int idx):
        cdef x = self.thisptr.at(idx).x
        cdef y = self.thisptr.at(idx).y
        cdef z = self.thisptr.at(idx).z
        return x,y,z

    def from_file(self, char *f):
        cdef string s = string(f)
        cdef int ok = cpp.loadPCDFile(s, deref(self.thisptr))
        return ok

    def make_segmenter(self):
        seg = Segmentation()
        cdef cpp.SACSegmentation_t *cseg = <cpp.SACSegmentation_t *>seg.me
        cdef cpp.PointCloud_t *ccloud = <cpp.PointCloud_t *>self.thisptr
        cseg.setInputCloud(ccloud.makeShared())
        return seg

    def make_segmenter_normals(self, int k):
        cdef cpp.PointNormalCloud_t normals
        mpcl_compute_normals(deref(self.thisptr), k, normals)

        seg = SegmentationNormal()
        cdef cpp.SACSegmentationNormal_t *cseg = <cpp.SACSegmentationNormal_t *>seg.me
        cdef cpp.PointCloud_t *ccloud = <cpp.PointCloud_t *>self.thisptr
        cseg.setInputCloud(ccloud.makeShared())
        cseg.setInputNormals (normals.makeShared());

        return seg

