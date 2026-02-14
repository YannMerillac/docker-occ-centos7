from OCC.Core.gp import gp_Pnt
from OCC.Core.TColgp import TColgp_Array1OfPnt
from OCC.Core.GeomAPI import GeomAPI_PointsToBSpline
from OCC.Core.BRepBuilderAPI import BRepBuilderAPI_MakeEdge, BRepBuilderAPI_MakeWire, BRepBuilderAPI_MakeFace
from OCC.Core.BRepOffsetAPI import BRepOffsetAPI_MakePipe
from OCC.Core.BRepAlgoAPI import BRepAlgoAPI_Cut
from OCC.Display.SimpleGui import init_display

def create_rect_profile(width, height):
    """Crée une face rectangulaire pleine."""
    w, h = width / 2.0, height / 2.0
    pts = [gp_Pnt(-w, -h, 0), gp_Pnt(w, -h, 0), gp_Pnt(w, h, 0), gp_Pnt(-w, h, 0)]
    edges = [BRepBuilderAPI_MakeEdge(pts[i], pts[(i+1)%4]).Edge() for i in range(4)]
    wire = BRepBuilderAPI_MakeWire(*edges).Wire()
    return BRepBuilderAPI_MakeFace(wire).Face()

# 1. Création de la trajectoire (Spline)
pts_list = [gp_Pnt(0,0,0), gp_Pnt(50,20,50), gp_Pnt(100,-20,100), gp_Pnt(150,0,150)]
points = TColgp_Array1OfPnt(1, len(pts_list))
for i, p in enumerate(pts_list): points.SetValue(i+1, p)

bspline = GeomAPI_PointsToBSpline(points).Curve()
path = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(bspline).Edge()).Wire()

# 2. Création des deux solides
thickness = 2.0
dim_ext = (20, 10)
dim_int = (dim_ext[0] - 2*thickness, dim_ext[1] - 2*thickness)

# Pipe Extérieur
face_ext = create_rect_profile(*dim_ext)
solid_ext = BRepOffsetAPI_MakePipe(path, face_ext).Shape()

# Pipe Intérieur
face_int = create_rect_profile(*dim_int)
solid_int = BRepOffsetAPI_MakePipe(path, face_int).Shape()

# 3. Soustraction Booléenne
tube_final = BRepAlgoAPI_Cut(solid_ext, solid_int).Shape()

# Visualisation
display, start_display, _, _ = init_display()
display.DisplayShape(tube_final, update=True)
start_display()
