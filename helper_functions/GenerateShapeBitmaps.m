function [bitmaps, vertices] = GenerateShapeBitmaps()
    % GENERATESHAPEBITMAPS - Generates bitmaps of predefined shapes for use
    % in drawing textures. Add to this file to include other shapes. Shapes
    % are defined by the pixel coordinates of their vertices, and are
    % normalized to the area of a circle with a radius of 50. All output
    % bitmaps are 256x256.
    % OUTPUTS:
    %    bitmaps - A struct containing 256x256 bitmaps for different shapes.
    %    vertices - A struct containing lists of vertex coordinates for different shapes.

    r = 50;
    circleArea = pi * r^2;

    % Implement any new shapes here
    GenerateCircle();
    GenerateTriangle();
    GenerateSquare();
    GenerateCross();

    function GenerateCircle()
        % Adds the 'Circle' property to the bitmaps and vertices structs.

        x = r * cosd(0:359);
        y = r * sind(0:359);
        [circle, verts] = bitmap256([x' y']);
        bitmaps.Circle = circle;
        vertices.Circle = verts;
    end

    function GenerateTriangle()
        % Adds the 'Triangle' property to the bitmaps and vertices structs.
        
        verts = nsidedpoly(3).Vertices;
        [triangle, verts] = bitmap256(verts);
        bitmaps.Triangle = triangle;
        vertices.Triangle = verts;
    end

    function GenerateSquare()
        % Adds the 'Square' property to the bitmaps and vertices structs.

        verts = nsidedpoly(4).Vertices;
        [square, verts] = bitmap256(verts);
        bitmaps.Square = square;
        vertices.Square = verts;
    end

    function GenerateCross()
        % Adds the 'Cross' property to the bitmaps and vertices structs.

        verts = [1,3; 1,1; 3,1; 3,-1; 1,-1; 1,-3; -1,-3; -1,-1; -3,-1; -3,1; -1,1; -1,3];
        [cross, verts] = bitmap256(verts);
        bitmaps.Cross = cross;
        vertices.Cross = verts;
    end

    function [bmp, vrt] = bitmap256(vertices)
        % Generates a 256x256 bitmap of the polygon defined by vertices, an
        % nx2 matrix of pixel coordinates. Output shapes are normalized to
        % the area of a circle of radius 50, and vertically flipped to
        % align with screen coordinates.
        % INPUTS:
        %    vertices: an Nx2 list of points defining the vertices of the polygon
        % OUTPUTS:
        %    bmp: a 256x256x2 matrix representing Luminance and Alpha channels
        %    vrt: the input list of vertices, after screen coordinate correction and normalization
        %       to the area of a circle.

        x = vertices(:,1);
        y = vertices(:,2);
        norm = sqrt(polyarea(x, y) / circleArea);
        x_corrected = x/norm + 128;
        y_corrected = -y/norm + 128;
        vrt = [x, y] ./ norm;

        mask = poly2mask(x_corrected, y_corrected, 256, 256);
        lum = double(mask);
        alpha = mask * 255;
        bmp(:, :, 1) = lum;
        bmp(:, :, 2) = alpha;
    end
end
